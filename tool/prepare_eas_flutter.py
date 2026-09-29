"""Write Flutter client configuration on the EAS builder without logging keys."""
import json
import os
from pathlib import Path


if __name__ == "__main__":
    names = ("SUPABASE_URL", "SUPABASE_ANON_KEY")
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise SystemExit("Set EAS production environment variables: " + ", ".join(missing))
    values = {name: os.environ[name] for name in names}
    values["REQUIRE_EMAIL_VERIFICATION"] = True
    target = Path(".eas/flutter-defines.json")
    target.write_text(json.dumps(values), encoding="utf-8")
    target.chmod(0o600)
