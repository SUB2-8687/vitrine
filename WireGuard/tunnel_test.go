package main

import (
	"io"
	"net"
	"net/netip"
	"testing"
	"time"
)

func mustAddrPort(s string) netip.AddrPort { return netip.MustParseAddrPort(s) }

// No WireGuard peer is synthesized here. Real tunnel acceptance uses the user's
// Proton profile through harness/wireguard/run_macos.py.
func TestProxyRejectsSpecialDestinations(t *testing.T) {
	for _, host := range []string{"127.0.0.1", "10.2.0.1", "169.254.169.254", "224.0.0.1",
		"0.0.0.0", "100.64.0.1", "192.0.2.1", "198.18.0.1", "203.0.113.1",
		"::1", "::ffff:127.0.0.1", "fe80::1", "fc00::1", "2001:db8::1", "2002:7f00:1::"} {
		t.Run(host, func(t *testing.T) {
			_, client, done := pipeEngine()
			defer client.Close()
			if reply := socksHandshake(t, client, []byte{2}, "user-0123", "pass-4567"); reply[1] != 0 {
				t.Fatal("fixture authentication failed")
			}
			request := append([]byte{5, 1, 0, 3, byte(len(host))}, host...)
			request = append(request, 1, 187)
			if _, err := client.Write(request); err != nil {
				t.Fatal(err)
			}
			reply := make([]byte, 10)
			if _, err := io.ReadFull(client, reply); err != nil {
				t.Fatal(err)
			}
			if reply[0] != 5 || reply[1] != 4 {
				t.Fatal("special-use destination was not refused")
			}
			client.Close()
			<-done
		})
	}
}

func TestUnauthenticatedProxyCapacity(t *testing.T) {
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	e := &Engine{listener: listener, clients: map[net.Conn]struct{}{},
		pendingAuth: make(chan struct{}, maxUnauthenticatedClients)}
	finished := make(chan struct{})
	go func() { e.acceptLoop(listener); close(finished) }()
	var clients []net.Conn
	defer func() {
		e.stopped.Store(true)
		listener.Close()
		for _, client := range clients {
			client.Close()
		}
		<-finished
	}()
	for i := 0; i < 32; i++ {
		client, err := net.Dial("tcp4", listener.Addr().String())
		if err != nil {
			t.Fatal(err)
		}
		clients = append(clients, client)
		client.SetDeadline(time.Now().Add(time.Second))
		client.Write([]byte{5, 1, 2})
		reply := make([]byte, 2)
		if _, err := io.ReadFull(client, reply); err != nil {
			t.Fatal(err)
		}
		if reply[0] != 5 || reply[1] != 2 {
			t.Fatal("authentication negotiation refused below capacity")
		}
	}
	excess, err := net.Dial("tcp4", listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer excess.Close()
	excess.SetDeadline(time.Now().Add(time.Second))
	buffer := make([]byte, 1)
	if n, err := excess.Read(buffer); n != 0 || err == nil {
		t.Fatal("excess unauthenticated client remained open")
	} else if failure, ok := err.(net.Error); ok && failure.Timeout() {
		t.Fatal("excess unauthenticated client was not rejected immediately")
	}
}
