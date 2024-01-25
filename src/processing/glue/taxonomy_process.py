import sys

from pyspark import Row

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

from pyspark.sql.functions import from_json

def flat_counts(row):
   v_id = row[0]
   if row[1] is None:
      return [Row(tax_id=v_id, count=0, type='')]
   else:
       v_count = [ Row(tax_id=v_id, count=x['count'], type=x['type']) for x in row[1]]
       return v_count


args = getResolvedOptions(sys.argv, ["raw_path", "trusted_path"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init("taxonomy_process", args)
df = spark.read.json(args['raw_path'])

taxonomy_nodes = df.rdd.flatMap(lambda x: x.taxonomy_nodes)
taxonomy = taxonomy_nodes.map(lambda x: x.taxonomy)

counts = taxonomy.map(lambda x: (x.tax_id, x.counts))
counts_table = counts.flatMap(flat_counts).toDF()
counts_table.createOrReplaceTempView("counts_table")

taxonomy_table = taxonomy.map(lambda x: Row(tax_id=x.tax_id, common_name=x.common_name, organism_name=x.organism_name, rank=x.rank)).toDF()
taxonomy_table.createOrReplaceTempView("taxonomy_table")

# Create taxonomy table if not exists
if not spark.catalog.tableExists('glue_catalog.`geekfox-pawprint-trusted`.taxonomy'):
    taxonomy_table \
     .writeTo("glue_catalog.`geekfox-pawprint-trusted`.taxonomy") \
     .using('iceberg') \
     .tableProperty('location', args['trusted_path'] + '/taxonomy') \
     .tableProperty('write.format.default', 'parquet') \
     .createOrReplace()
else:
    # Merge mechanics - CDC
    sql = """
        WITH changes AS
            SELECT 
              COALESCE(b.tax_id, a.tax_id) AS tax_id,
              b.common_name as common_name,
              b.organism_name as organism_name,
              b.rank as rank
              CASE WHEN b.tax_id IS NULL THEN 'D' WHEN a.tax_id IS NULL THEN 'I' ELSE 'U' END as cdc
            FROM `glue_catalog.geekfox-pawprint-trusted`.taxonomy a
            FULL OUTER JOIN taxonomy_table b ON a.tax_id = b.tax_id
            WHERE NOT (a.common_name = b.common_name AND a.organism_name = b.organism_name AND a.rank = b.rank)

            MERGE INTO `glue_catalog.geekfox-pawprint-trusted`.taxonomy
            USING changes
            ON `glue_catalog.geekfox-pawprint-trusted`.taxonomy.tax_id = changes.tax_id
            WHEN MATCHED AND changes.cdc = 'D' THEN DELETE
            WHEN MATCHED AND changes.cdc = 'U' THEN UPDATE SET *
            WHEN NOT MATCHED THEN INSERT *
    """
    spark.sql(sql)
#  Create counts table
if not spark.catalog.tableExists('glue_catalog.`geekfox-pawprint-trusted`.taxonomy_counts'):
    counts_table \
        .writeTo("glue_catalog.`geekfox-pawprint-trusted`.taxonomy_counts") \
        .using('iceberg') \
        .tableProperty('location', args['trusted_path'] + '/taxonomy_counts') \
        .tableProperty('write.format.default', 'parquet') \
        .createOrReplace()
else:
    # Merge mechanics - CDC
    sql = """
        WITH changes AS
            SELECT 
              COALESCE(b.tax_id, a.tax_id) AS tax_id,
              b.count as count,
              b.type as type
              CASE WHEN b.tax_id IS NULL THEN 'D' WHEN a.tax_id IS NULL THEN 'I' ELSE 'U' END as cdc
            FROM `glue_catalog.geekfox-pawprint-trusted`.taxonomy_counts a
            FULL OUTER JOIN counts_table b ON a.tax_id = b.tax_id
            WHERE NOT (a.count = b.count AND a.type = b.type)
            
            MERGE INTO `glue_catalog.geekfox-pawprint-trusted`.taxonomy_counts
            USING changes
            ON `glue_catalog.geekfox-pawprint-trusted`.taxonomy_counts.tax_id = changes.tax_id
            WHEN MATCHED AND changes.cdc = 'D' THEN DELETE
            WHEN MATCHED AND changes.cdc = 'U' THEN UPDATE SET *
            WHEN NOT MATCHED THEN INSERT *
    """
    spark.sql(sql)

job.commit()

