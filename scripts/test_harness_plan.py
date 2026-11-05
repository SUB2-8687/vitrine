import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("harness_plan", ROOT / "scripts/harness-plan.py")
planner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(planner)


class BuildInputSelection(unittest.TestCase):
    def test_reading_source_does_not_compile_its_imports(self):
        index = planner.build_index()
        for path, expected in [
            ("tweak/Sources/Redesigned/Lyrics/SGRKaraokeView.m", True),
            ("tweak/Sources/Redesigned/Lyrics/SGRKaraokeView.h", False),
        ]:
            with self.subTest(path=path):
                selected, _, _ = planner.plan(index, [path], False)
                self.assertEqual(expected, "Sing model-free" in {entry["name"] for entry in selected})

    def test_player_python_runner_keeps_its_compiled_inputs(self):
        index = planner.build_index()
        paths = [
            "tweak/Sources/Redesigned/Player/PlayerMix.x",
            "tweak/Sources/Redesigned/Player/PlayerSettings.m",
            "tweak/Sources/Redesigned/Player/PlayerControls.x",
            "tweak/Sources/Redesigned/Player/PlayerQueue.m",
            "tweak/Sources/Redesigned/Player/PlayerArtwork.x",
            "tweak/Sources/Shared/AutoMix/AutoMixSettings.m",
        ]
        for path in paths:
            with self.subTest(path=path):
                selected, _, _ = planner.plan(index, [path], False)
                self.assertLessEqual(
                    {"Player settings", "Player AutoMix UI"},
                    {entry["name"] for entry in selected},
                )


if __name__ == "__main__":
    unittest.main()
