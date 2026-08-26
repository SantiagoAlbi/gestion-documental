"""
Lambda: lights-off
Trigger: EventBridge Scheduler (2 schedules: associate a la mañana, disassociate a la noche)

Responsabilidad:
  - action == "associate": asociar cada subnet de SUBNET_IDS al Client VPN
    endpoint (si no está ya asociada).
  - action == "disassociate": desasociar todas las asociaciones activas.

No usa Terraform para estas asociaciones a propósito — ver la nota en
network/client-vpn.tf. Este es el único lugar que las gestiona.
"""

import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2_client = boto3.client("ec2")

CLIENT_VPN_ENDPOINT_ID = os.environ["CLIENT_VPN_ENDPOINT_ID"]
SUBNET_IDS = os.environ["SUBNET_IDS"].split(",")


def get_active_associations() -> list:
    response = ec2_client.describe_client_vpn_target_networks(
        ClientVpnEndpointId=CLIENT_VPN_ENDPOINT_ID
    )
    return [
        network
        for network in response.get("ClientVpnTargetNetworks", [])
        if network["Status"]["Code"] not in ("disassociated", "disassociating")
    ]


def associate() -> None:
    active = {net["TargetNetworkId"] for net in get_active_associations()}

    for subnet_id in SUBNET_IDS:
        if subnet_id in active:
            logger.info("Subnet %s ya asociada, se omite", subnet_id)
            continue

        logger.info("Asociando subnet %s", subnet_id)
        ec2_client.associate_client_vpn_target_network(
            ClientVpnEndpointId=CLIENT_VPN_ENDPOINT_ID,
            SubnetId=subnet_id,
        )


def disassociate() -> None:
    for network in get_active_associations():
        association_id = network["AssociationId"]
        logger.info("Desasociando %s", association_id)
        ec2_client.disassociate_client_vpn_target_network(
            ClientVpnEndpointId=CLIENT_VPN_ENDPOINT_ID,
            AssociationId=association_id,
        )


def lambda_handler(event, context):
    action = event.get("action")
    logger.info("Lights-Off action=%s", action)

    if action == "associate":
        associate()
    elif action == "disassociate":
        disassociate()
    else:
        raise ValueError(f"Acción no reconocida: {action}")

    return {"statusCode": 200, "action": action}
