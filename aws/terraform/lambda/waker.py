"""Locator + waker for the Minecraft Earth client.

The patched APK's locator points at this function's URL. On launch the game requests
<url>/api/v1.1/player/environment. We start the game server if it is stopped and answer with the
same locator JSON the real server would, so the game proceeds to the server's address.

A cold start takes the server a couple of minutes to boot and bring up all components, so the
first launch after a sleep errors out ("can't connect"); relaunching once it is up works.
"""
import json
import os

import boto3

INSTANCE_ID = os.environ["INSTANCE_ID"]
SERVICE_URI = os.environ["SERVICE_URI"].rstrip("/")

ec2 = boto3.client("ec2")

LOCATOR = {
    "result": {
        "serviceEnvironments": {
            "production": {
                "serviceUri": SERVICE_URI,
                "cdnUri": SERVICE_URI + "/cdn",
                "playfabTitleId": "20CA2",
            }
        },
        "supportedEnvironments": {
            "2020.1217.02": ["production"],
            "2020.1210.01": ["production"],
        },
    },
    "updates": {},
}


def handler(event, context):
    try:
        state = ec2.describe_instances(InstanceIds=[INSTANCE_ID])["Reservations"][0]["Instances"][0]["State"]["Name"]
        if state == "stopped":
            ec2.start_instances(InstanceIds=[INSTANCE_ID])
            print(f"started {INSTANCE_ID}")
        else:
            print(f"{INSTANCE_ID} is {state}")
    except Exception as exc:  # never let a wake failure break the locator answer
        print(f"wake error: {exc}")

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(LOCATOR),
    }
