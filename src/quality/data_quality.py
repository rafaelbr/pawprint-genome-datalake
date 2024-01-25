import io
import json
import logging
import os
import boto3
import pandas as pd
import jsonschema

import pre_process

from urllib.parse import unquote

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

    if len(key_parts) < 4:
        logger.error('Invalid key')
        return None

    suggested_database = key_parts[1]
    suggested_table = key_parts[2]
    partition = ""
    if len(key_parts) > 4:
        partition = key_parts[3]
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
                            'trusted_process': t['trusted_process'],
                            'records_node': t['records_node']
                        }
                    elif t['partition'] == partition.split('=')[0]:
                        data = {
                            'database': d['name'],
                            'table': t['name'],
                            'partition': partition,
                            'preprocess': t['preprocess'],
                            'trusted_process': t['trusted_process'],
                            'records_node': t['records_node']
                        }
                    break
            break
    return data


def validate_against_schema(data):
    # get schema file
    schema = json.loads(read_from_s3(AWS_RESOURCES_BUCKET, f'schemas/{data["info"]["table"]}_schema.json'))

    # adjust schema to match list of records
    properties = schema['properties']

    schema = {
        '$schema': 'http://json-schema.org/draft-04/schema#',
        'type': 'object',
        'properties': {
            'taxonomy_nodes': {
                'type': 'array',
                'items': {
                    'type': 'object',
                    'properties': properties
                }
            }
        }
    }

    schema['properties']['taxonomy_nodes']['properties'] = properties

    body = read_from_s3(data['bucket'], data['key'])
    json_data = json.loads(body)

    try:
        jsonschema.validate(json_data, schema)
        return {
            'success': True,
            'results': {}
        }
    except Exception as e:
        logger.error('Schema validation failed')
        return {
            'success': False,
            'results': {
                'error': str(e.message),
            }
        }


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
        key = unquote(record['s3']['object']['key'])

        if not 'pending' in key.split('/'):
            logger.info('File is not pending')
            continue

        logger.info('Starting quality validation - Bucket: {}, Key: {}'.format(bucket, key))

        if not check_file_exists_s3(bucket, key):
            logger.error('File does not exist in S3')
            continue

        data = process_s3_file(bucket, key)

        if data is None:
            logger.error('No config matched the file')
            continue

        results = validate_against_schema(data)

        send_to_sns(json.dumps(results))

        if results['success']:
            logger.info('Quality finished - Validation successful')
            send_to_sqs(json.dumps(format_queue_message(data)))
            continue

        logger.info('Quality finished - Validation failed')



    return {
        'statusCode': 200,
        'body': json.dumps('Execution done!')
    }

