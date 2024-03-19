#!/bin/bash


BUCKET=public-test-`date +%s`
aws s3 mb s3://$BUCKET
aws s3api delete-public-access-block --bucket $BUCKET


cat <<EOF > policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET/*"
        }
    ]
}
EOF
aws s3api put-bucket-policy --bucket $BUCKET --policy file://policy.json
rm policy.json
