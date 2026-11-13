package main

import (
	"context"
	"errors"
	"net/netip"
)

// Conservative public-destination policy: Spotify does not require IANA
// special-purpose networks. DNS servers from the trusted profile are used only
// by netstack's resolver, not admitted as client TCP destinations.
var specialDestinations = []netip.Prefix{
	netip.MustParsePrefix("0.0.0.0/8"),
	netip.MustParsePrefix("100.64.0.0/10"),
	netip.MustParsePrefix("192.0.0.0/24"),
	netip.MustParsePrefix("192.0.2.0/24"),
	netip.MustParsePrefix("192.88.99.0/24"),
	netip.MustParsePrefix("198.18.0.0/15"),
	netip.MustParsePrefix("198.51.100.0/24"),
	netip.MustParsePrefix("203.0.113.0/24"),
	netip.MustParsePrefix("240.0.0.0/4"),
	netip.MustParsePrefix("2001::/23"),
	netip.MustParsePrefix("2001:db8::/32"),
	netip.MustParsePrefix("2002::/16"),
	netip.MustParsePrefix("3fff::/20"),
}

var publicIPv6 = netip.MustParsePrefix("2000::/3")
var errDestination = errors.New("destination is not public unicast")

func publicDestination(address netip.Addr) bool {
	address = address.Unmap()
	if !address.IsGlobalUnicast() || address.IsPrivate() || address.Zone() != "" {
		return false
	}
	if address.Is6() && !publicIPv6.Contains(address) {
		return false
	}
	for _, prefix := range specialDestinations {
		if prefix.Contains(address) {
			return false
		}
	}
	return true
}

func (e *Engine) destinationAddresses(ctx context.Context, host string) ([]netip.Addr, error) {
	values := []string{host}
	if _, err := netip.ParseAddr(host); err != nil {
		var lookupErr error
		values, lookupErr = e.stack.LookupContextHost(ctx, host)
		if lookupErr != nil {
			return nil, lookupErr
		}
	}
	if len(values) == 0 {
		return nil, errDestination
	}
	addresses := make([]netip.Addr, 0, len(values))
	for _, value := range values {
		address, err := netip.ParseAddr(value)
		if err != nil || !publicDestination(address) {
			return nil, errDestination
		}
		addresses = append(addresses, address.Unmap())
	}
	return addresses, nil
}
