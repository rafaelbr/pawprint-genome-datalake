import io
import json
import logging
import os
import boto3
import pandas as pd

import pre_process

from great_expectations.data_context import BaseDataContext
from great_expectations.data_context.types.base import DatasourceConfig, DataContextConfig
from great_expectations.dataset import PandasDataset
import great_expectations as gx

CONFIG_BUCKET = os.getenv('CONFIG_BUCKET')
CONFIG_PATH = os.getenv('CONFIG_PATH')
AWS_RESOURCES_BUCKET = os.getenv('AWS_RESOURCES_BUCKET')
GX_PATH = os.getenv('GX_PATH')
QUEUE_NAME = os.getenv('QUEUE_NAME')
SNS_TOPIC = os.getenv('SNS_TOPIC_ARN')

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def read_config():
    s3 = boto3.resource('s3')
    obj = s3.Object(CONFIG_BUCKET, CONFIG_PATH)
    body = obj.get()['Body'].read()
    return json.loads(body)


config = read_config()

def read_from_s3(bucket, key):
    s3 = boto3.resource('s3')
    obj = s3.Object(bucket, key)
    body = obj.get()['Body'].read()
    return body

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


def check_database_config(bucket, key):
    key_parts = key.split('/')

    if len(key_parts) < 3:
        logger.error('Invalid key')
        return None

    suggested_database = key_parts[0]
    suggested_table = key_parts[1]
    partition = ""
    if len(key_parts) > 3:
        partition = key_parts[2]
    file = key_parts[-1]

    data = None
    for d in config['databases']:
        if d['name'] == suggested_database:
            for t in d['tables']:
                if t['name'] == suggested_table:
                    if t['partition'] == '':
                        data = {
                            'database': d['name'],
                            'table': t['name'],
                            'partition': '',
                            'preprocess': t['preprocess'],
                        }
                    elif t['partition'] == partition.split('=')[0]:
                        data = {
                            'database': d['name'],
                            'table': t['name'],
                            'partition': partition,
                            'preprocess': t['preprocess'],
                        }
                    break
            break
    return data


def validate_with_great_expectations(data):
    data_context_config = DataContextConfig(
        datasources={
            "pandas_datasource": DatasourceConfig(
                class_name="PandasDatasource"
            )
        },
        stores={
            "expectations_S3_store": {
                "class_name": "ExpectationsStore",
                "store_backend": {
                    "class_name": "TupleS3StoreBackend",
                    "bucket": CONFIG_BUCKET,
                    "prefix": GX_PATH
                }
            }
        },
        expectations_store_name="expectations_S3_store"
    )

    context = gx.get_context(data_context_config)
    suite = context.get_expectation_suite('{}.{}'.format(data['info']['database'], data['info']['table']))
    batch = PandasDataset(data['df'], expectation_suite=suite)
    results = batch.validate()

    return results

def process_s3_file(bucket, key):
    data = check_database_config(bucket, key)
    if data is None:
        logger.error('No config matched the file')
        return None
    body = read_from_s3(bucket, key)

    preprocess = getattr(pre_process, data['preprocess'])

    df = pd.read_json(io.StringIO(body.decode('utf-8')))
    logger.info('Columns found: {}'.format(df.columns))
    df = preprocess(df)
    logger.info('Columns processed: {}'.format(df.columns))
    return {
        'info': data,
        'bucket': bucket,
        'key': key,
        'df': df
    }

def send_to_sqs(message):
    sqs = boto3.resource('sqs')
    queue = sqs.get_queue_by_name(QueueName=QUEUE_NAME)
    response = queue.send_message(MessageBody=message)
    return response

def send_to_sns(message):
    sns = boto3.resource('sns')
    topic = sns.Topic(SNS_TOPIC)
    response = topic.publish(Message=message)
    return response

def format_report(results):
    report = {
        'success': False,
        'results': []
    }

    if results['success']:
        report['success'] = True
        return report

    for result in results['results']:
        report['results'].append({
            'expectation_type': result['expectation_config']['expectation_type'],
            'kwargs': result['expectation_config']['kwargs'],
            'success': result['success'],
            'result': result['result']
        })

    return report

def format_queue_message(data):
    return {
        'info': data['info'],
        'bucket': data['bucket'],
        'key': data['key'],
    }

def lambda_handler(event, context):
    logger.info('Event: {}'.format(event))

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        logger.info('Starting quality validation - Bucket: {}, Key: {}'.format(bucket, key))

        if not check_file_exists_s3(bucket, key):
            logger.error('File does not exist in S3')
            continue

        data = process_s3_file(bucket, key)

        if data is None:
            logger.error('No config matched the file')
            continue

        results = validate_with_great_expectations(data)

        report = format_report(results)

        send_to_sns(json.dumps(report))

        if report['success']:
            logger.info('Quality finished - Validation successful')
            send_to_sqs(json.dumps(format_queue_message(data)))
            continue

        logger.info('Quality finished - Validation failed')



    return {
        'statusCode': 200,
        'body': json.dumps('Execution done!')
    }

