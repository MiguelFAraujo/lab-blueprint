# registro: 2026-10-19 | autor: Miguel (via OpenCode) | modelo: opencode/big-pickle
"""R009-C: embedded copies must not drift from the canonical files."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return (ROOT / name).read_text(encoding="utf-8")


def setup_heredoc():
    match = re.search(r"<< 'DOCKERCOMPOSE'\n(.*?)\nDOCKERCOMPOSE", read("setup.sh"), re.S)
    return match.group(1).strip() if match else None


class ConsistencyTest(unittest.TestCase):
    def test_setup_heredoc_matches_canonical_compose(self):
        self.assertIsNotNone(setup_heredoc(), "heredoc DOCKERCOMPOSE ausente no setup.sh")
        self.assertEqual(setup_heredoc(), read("docker-compose.yml").strip())

    def test_readme_does_not_embed_stale_setup_copy(self):
        readme = read("README.md")
        self.assertIn("./setup.sh", readme)
        self.assertNotIn("mkdir -p /home/$USER", readme)
        self.assertNotIn('echo "🚀 Iniciando setup do Laboratório..."', readme)


if __name__ == "__main__":
    unittest.main()
