import sys
from datetime import datetime

from pyspark import Row

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import lit
from awsglue.context import GlueContext
from awsglue.job import Job

import awswrangler as wr
import pandas as pd
import boto3
import json

from pyspark.sql.functions import from_json

args = getResolvedOptions(sys.argv, ["raw_path", "trusted_path", "config_bucket"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init("dataset_report_process", args)

#process dataset with pandas
path = '/'.join(args['raw_path'].split('/')[:-1])+'/'
df = wr.s3.read_json(path, lines=True)

final_list = []
for i in df['reports']:
    final_list.extend(i)

df = pd.json_normalize(final_list)

org_df = pd.json_normalize(final_list, 'organelle_info', ['accession'])

s3 = boto3.resource('s3')
obj = s3.Object(args['config_bucket'], 'utils/dataset_report_columns.json')
body = obj.get()['Body'].read()
columns = json.loads(body)

df = df[columns]
df = df.astype(str)
org_df = org_df.astype(str)

#convert to spark dataframes
reports_df = spark.createDataFrame(df)
reports_df = reports_df.withColumn('process_date', lit(datetime.now().strftime("%Y-%m-%d")))
reports_df.createOrReplaceTempView("reports_table")
organelle_df = spark.createDataFrame(org_df)
reports_df = reports_df.withColumn('process_date', lit(datetime.now().strftime("%Y-%m-%d")))
organelle_df.createOrReplaceTempView("organelle_table")

# Create taxonomy table if not exists
reports_df \
     .writeTo("glue_catalog.`geekfox-pawprint-trusted`.genome_dataset_report") \
     .using('iceberg') \
     .tableProperty('location', args['trusted_path'] + '/genome/dataset_report') \
     .tableProperty('write.format.default', 'parquet') \
     .createOrReplace()

organelle_df \
    .writeTo("glue_catalog.`geekfox-pawprint-trusted`.genome_organelle") \
    .using('iceberg') \
    .tableProperty('location', args['trusted_path'] + '/genome/organelle') \
    .tableProperty('write.format.default', 'parquet') \
    .createOrReplace()

job.commit()

