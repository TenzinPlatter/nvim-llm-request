#!/usr/bin/env python3
"""
AI Request backend - handles LLM API calls via stdio JSON protocol.
"""
import sys
import json

def main():
    """Main stdio loop."""
    for line in sys.stdin:
        try:
            message = json.loads(line)
            # TODO: Route messages
            response = {"type": "error", "message": "Not implemented"}
            print(json.dumps(response), flush=True)
        except Exception as e:
            error = {"type": "error", "message": str(e)}
            print(json.dumps(error), flush=True)

if __name__ == "__main__":
    main()
