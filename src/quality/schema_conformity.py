import io
import json
import logging
import os
from datetime import datetime

import boto3
import jsonpointer

CONFIG_BUCKET = os.getenv('CONFIG_BUCKET')
CONFIG_PATH = os.getenv('CONFIG_PATH')
AWS_RESOURCES_BUCKET = os.getenv('AWS_RESOURCES_BUCKET')
QUEUE_NAME = os.getenv('QUEUE_NAME')

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

def copy_to_s3(bucket, key, data):
    s3 = boto3.resource('s3')
    obj = s3.Object(bucket, key)
    obj.put(Body=data)

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

def send_to_sqs(message):
    sqs = boto3.resource('sqs')
    queue = sqs.get_queue_by_name(QueueName=QUEUE_NAME)
    response = queue.send_message(MessageBody=message)
    return response

def format_queue_message(data):
    return {
        'info': data['info'],
        'bucket': data['bucket'],
        'key': data['key'],
    }

def fill_missing_fields(data, schema):
    for field_name, field_schema in schema.get('properties', {}).items():
        #print('processing field', field_name)
        if field_schema.get("type") == "object":
            #print('processing object', field_schema)
            # Recursively handle nested fields
            try:
                nested_data = jsonpointer.resolve_pointer(data, f"/{field_name}")
            except:
                nested_data = {}  # Create the nested object if missing
            nested_data = fill_missing_fields(nested_data, field_schema)
            jsonpointer.set_pointer(data, f"/{field_name}", nested_data)
        elif field_schema.get("type") == "array":
            # Recursively handle nested fields
            try:
                nested_data = jsonpointer.resolve_pointer(data, f"/{field_name}")
            except:
                nested_data = []  # Create the nested object if missing
            for i in range(len(nested_data)):
                nested_data[i] = fill_missing_fields(nested_data[i], field_schema.get("items"))
            jsonpointer.set_pointer(data, f"/{field_name}", nested_data)
        else:
            if field_name not in data:
                jsonpointer.set_pointer(data, f"/{field_name}", None)

    return data

def lambda_handler(event, context):
    logger.info('Event: {}'.format(event))

    for record in event['Records']:
        body = json.loads(record['body'])
        bucket = body['bucket']
        key = body['key']
        info = body['info']
        logger.info(f"Found data from bucket: {bucket}, key: {key}")

        if 'pending' in key.split('/'):
            logger.info('Processing pending file - Bucket: {}, Key: {}'.format(bucket, key))

            if not check_file_exists_s3(bucket, key):
                logger.error('File does not exist in S3')
                continue

            data = read_from_s3(bucket, key)
            db_config = check_database_config(bucket, key)

            # get schema file
            schema = read_from_s3(AWS_RESOURCES_BUCKET, f'schemas/{db_config["table"]}_schema.json')

            final_data = {
                db_config['records_node']: []
            }
            for record in json.loads(data)[db_config['records_node']]:
                record = fill_missing_fields(record, json.loads(schema))
                final_data[db_config['records_node']].append(record)

            key = key.replace('pending/', 'processed/')

            copy_to_s3(bucket, key, json.dumps(final_data))
            logger.info('File processed - Bucket: {}, Key: {}'.format(bucket, key))
            message_data = {
                'info': info,
                'bucket': bucket,
                'key': key,
            }
            send_to_sqs(json.dumps(format_queue_message(message_data)))


