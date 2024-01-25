import json
import logging
import os
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def check_file_exists_s3(bucket, key):
    s3 = boto3.resource('s3')

    return_var = False
    try:
        s3.Object(bucket, key).load()
        return_var = True
    except Exception as e:
        print(e)
        return_var = False

    return return_var

def lambda_handler(event, context):
    logger.info(event)
    for record in event['Records']:
        body = json.loads(record['body'])
        bucket = body['bucket']
        key = body['key']
        info = body['info']
        logger.info(f"Found data from bucket: {bucket}, key: {key}")
        if not check_file_exists_s3(bucket, key):
            logger.info(f"File not found")
            continue
        if 'trusted_process' not in info or info['trusted_process'] is None:
            logger.info(f"Trusted Process not found")
            continue
        glue = boto3.client('glue')
        job_runs = glue.get_job_runs(JobName=info['trusted_process'])
        if len(job_runs['JobRuns']) > 0:
            is_running = False
            for job_run in job_runs['JobRuns']:
                if job_run['JobRunState'] == 'RUNNING':
                    logger.info(f"Job already running")
                    is_running = True
                    break
            if is_running:
                continue
        logger.info(f"Start Glue Process Job {info['trusted_process']}")
        glue.start_job_run(JobName=info['trusted_process'], Arguments={
            '--raw_path': f"s3://{bucket}/{key}"
        })

