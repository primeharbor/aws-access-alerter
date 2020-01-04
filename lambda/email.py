import boto3
from botocore.exceptions import ClientError
import json
import os
import datetime
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import logging
logger = logging.getLogger()

if os.environ['DEBUG'] == "True":
    logger.setLevel(logging.DEBUG)
else:
    logger.setLevel(logging.INFO)

logging.getLogger('botocore').setLevel(logging.WARNING)
logging.getLogger('boto3').setLevel(logging.WARNING)
logging.getLogger('urllib3').setLevel(logging.WARNING)


def handler(event, context):
    logger.debug("Received event: " + json.dumps(event, sort_keys=True))
    message = json.loads(event['Records'][0]['Sns']['Message'])
    logger.info("Received message: " + json.dumps(message, sort_keys=True))

    # Structure of the Finding
    # {
    #   "version": "0",
    #   "id": "081668c3-90e7-a9ca-f284-9cb4b2396a4d",
    #   "detail-type": "Access Analyzer Finding",
    #   "source": "aws.access-analyzer",
    #   "account": "012345678901",
    #   "time": "2019-12-07T17:36:45Z",
    #   "region": "us-east-1",
    #   "resources": [
    #     "arn:aws:access-analyzer:us-east-1:012345678901:analyzer/aws-iam-access-alerter"
    #   ],
    #   "detail": {
    #     "version": "1.0",
    #     "id": "b1087d63-331c-4433-84f2-a973c7ae1313",
    #     "status": "ACTIVE",
    #     "resourceType": "AWS::IAM::Role",
    #     "resource": "arn:aws:iam::012345678901:role/fnord",
    #     "createdAt": "2019-12-07T17:36:42Z",
    #     "analyzedAt": "2019-12-07T17:36:42Z",
    #     "updatedAt": "2019-12-07T17:36:42Z",
    #     "accountId": "012345678901",
    #     "region": "us-east-1",
    #     "principal": {
    #       "AWS": "987654321098"
    #     },
    #     "action": [
    #       "sts:AssumeRole"
    #     ],
    #     "condition": {},
    #     "isDeleted": false,
    #     "isPublic": false
    #   }
    # }

    finding = message['detail']
    if finding['status'] != "ACTIVE":
        logger.debug(f"Finding is of status: {finding['status']}")
        return(event)

    if 'error' in finding and finding['error'] == "ACCESS_DENIED":
        logger.debug(f"Unable to access resource {finding['resource']}")
        return(event)


    try:

        iam_client = boto3.client('iam')
        response = iam_client.list_account_aliases()
        if 'AccountAliases' in response and len(response['AccountAliases']) > 0:
            account_alias = response['AccountAliases'][0]
            account_desc = f"{account_alias}({finding['accountId']})"
        else:
            account_alias = None
            account_desc = f"{finding['accountId']}"

        # Make some notes based on attributes of the finding
        if finding['isPublic']:
            subject = f"New Public Resource found in {account_desc}"
            intro = f"A New Public Resource has been discovered in your account {account_desc}:"
            explanation = "This resource can be accessed by anyone on the Internet"
        elif finding['resourceType'] == "AWS::IAM::Role" and 'Federated' in finding['principal']:
            subject = f"New SAML Federation found in {account_desc}"
            intro = f"A New SAML Federation has been discovered in {account_desc}: "
            explanation = "Make sure the identity provider noted above as the Trusted Entity belongs to your organization and has appropriate security controls in place."
        elif finding['resourceType'] == "AWS::IAM::Role":
            subject = f"New cross-account role found in {account_desc}"
            intro = f"A New cross-account role has been discovered in {account_desc}: "
            explanation = "The trusted entity above has permissions to perform actions in your account. You should validate that account's identity and perform a risk-assessment on it. \n Note: The actions that can be performed are not reported by the IAM Access Analyzer and should be inspected for least privilege."
        elif 'AWS' in finding['principal'] and finding['principal']['AWS'] == "*":
            subject = f"New un-authenticated resource found in {account_desc}"
            intro = f"A New resource has been discovered in {account_desc} that does not require IAM Authentication: "
            explanation = "The above resource does not require AWS IAM Authentication to access. All security measures rely on the conditions noted above"
        else:
            subject = f"New Resource trust found in {account_desc}"
            intro = f"A New Trust has been discovered in your account {account_desc}: "
            explanation = "The above resource is accessible to the Trusted Entity for the actions noted above"

        # Show account number of * if that's the trust, otherwise the entire principal in json.
        if 'AWS' in finding['principal']:
            trusted_entity = finding['principal']['AWS']
        else:
            trusted_entity = finding['principal']

        # Create a message body
        txt_body = f"""{intro}
Resource: {finding['resource']}
Type: {finding['resourceType']}
Region: {finding['region']}
Trusted Entity: {trusted_entity}
Actions: {json.dumps(finding['action'], sort_keys=True)}
Conditions: {finding['condition']}

{explanation}
"""

        html_body = f"""{intro}<p>
            <b>Resource:</b> {finding['resource']}<br>
            <b>Type:</b> {finding['resourceType']}<br>
            <b>Region:</b> {finding['region']}<br>
            <b>Trusted Entity:</b> {trusted_entity}<br>
            <b>Actions:</b> {json.dumps(finding['action'], sort_keys=True)}<br>
            <b>Conditions:</b> {finding['condition']}<br>
            <p>
            {explanation}
            """

        logger.info(f"Subject: {subject}\n Body: {txt_body}")
        send_email(subject, txt_body, html_body)
        return(event)

    except ClientError as e:
        logger.critical("AWS Error getting info: {}".format(e))
        raise
    except Exception as e:
        logger.critical("{}".format(e))
        raise

def send_email(subject, txt_body, html_body):

    # Always send emails via us-east-1 where SES is available and configured
    ses_client = boto3.client('ses', region_name='us-east-1')

    message = MIMEMultipart()
    message['From'] = os.environ['EMAIL_FROM']
    message['To'] = os.environ['EMAIL_TO']
    message['Subject'] = subject

    body = MIMEMultipart('alternative')
    body.attach(MIMEText(txt_body, 'plain')) # Text body of the email
    body.attach(MIMEText(html_body, 'html')) # HTML body of the email
    message.attach(body)

    logger.info("Sending email to {}".format(message['To']))
    response = ses_client.send_raw_email(
        Source=message['From'],
        RawMessage={
         'Data': message.as_string(),
    })

### END OF CODE ###

