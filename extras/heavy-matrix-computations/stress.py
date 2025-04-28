import json
import numpy as np
import subprocess
import sys
import argparse

# Usage:
# python3 stress.py          # Uses 400x400
# python3 stress.py --size 1000   # Uses 1000x1000

# Clean up files
# import os
# os.remove(PAYLOAD_FILE)
# os.remove(RESPONSE_FILE)

PAYLOAD_FILE = "payload.json"
RESPONSE_FILE = "response.json"
API_URL = "https://fermyon-z9gfcobv.fermyon.app/light-compute"

def generate_matrix(size=400):
    """Generate a random integer matrix of given size."""
    return np.random.randint(0, 10, size=(size, size)).tolist()

def save_payload(matrixA, matrixB, filename):
    """Save the matrices to a JSON payload file."""
    payload = {
        "matrixA": matrixA,
        "matrixB": matrixB
    }
    with open(filename, "w") as f:
        json.dump(payload, f)

def post_payload(payload_file, url):
    """Use curl to POST the payload and return the response."""
    try:
        result = subprocess.run([
            "curl", "-s", "-S", "-X", "POST", url,
            "-H", "Content-Type: application/json",
            "-d", f"@{payload_file}"
        ], capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print("❌ Curl failed:")
        print("stderr:", e.stderr)
        sys.exit(1)

def save_response(response_text, filename):
    """Save the response text to a JSON file."""
    with open(filename, "w") as f:
        f.write(response_text)

def parse_response(filename):
    """Load and inspect the response."""
    try:
        with open(filename) as f:
            data = json.load(f)
        result = data.get("resultMatrix")
        if result and isinstance(result, list):
            rows = len(result)
            cols = len(result[0]) if rows > 0 else 0
            print(f"✅ Received result matrix of shape: {rows} x {cols}")
        else:
            print("⚠️ No valid 'resultMatrix' field in response.")
        exec_time = data.get("executionDuration")
        if exec_time is not None:
            print(f"⏱️ Execution time: {exec_time:.6f} milliseconds")
    except Exception as e:
        print("❌ Failed to parse response:", e)

def main():
    parser = argparse.ArgumentParser(description="Matrix multiplication client")
    parser.add_argument(
        "--size",
        type=int,
        default=400,
        help="Size of the square matrices to generate (default: 400)"
    )
    args = parser.parse_args()

    print(f"🧮 Generating matrices of size {args.size}x{args.size}...")

    matrixA = generate_matrix(size=args.size)
    matrixB = generate_matrix(size=args.size)

    print("💾 Saving payload...")
    save_payload(matrixA, matrixB, PAYLOAD_FILE)

    print(f"📡 Sending payload to {API_URL}...")
    response_text = post_payload(PAYLOAD_FILE, API_URL)

    print("📥 Saving response...")
    save_response(response_text, RESPONSE_FILE)

    print("🔍 Parsing response...")
    parse_response(RESPONSE_FILE)

if __name__ == "__main__":
    main()
