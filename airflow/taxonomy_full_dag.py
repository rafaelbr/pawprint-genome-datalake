import json
import os
import shutil
from datetime import datetime

from airflow import DAG
from airflow.decorators import task
from airflow.providers.amazon.aws.transfers.local_to_s3 import LocalFilesystemToS3Operator
from airflow.providers.http.hooks.http import HttpHook
from airflow.providers.http.operators.http import SimpleHttpOperator

AIRFLOW_HOME = '/opt/airflow/dags/repo'

with DAG(
    dag_id='taxonomy_full',
    tags=['taxonomy', 'full-load', 'manual'],
    start_date=datetime(2023, 10, 20),
    schedule_interval=None
):
    @task()
    def init_job():
        os.mkdir('/opt/airflow/temp/taxonomy_full')

    def get_children_taxon(taxon_id, edges):
        children = []
        if taxon_id in edges and 'children_status' in edges[taxon_id] and edges[taxon_id]['children_status'] == 'HAS_MORE_CHILDREN':
            hook = HttpHook(http_conn_id='NCBI-DATASETS')
            response = hook.run(endpoint='taxonomy/filtered_subtree', data=json.dumps({'taxons': [taxon_id]}), headers={'Content-Type': 'application/json'})
            resp = response.json()
            edges = resp['edges']
            children = get_children_taxon(taxon_id, edges)
            children = [str(child) for child in children]
        if taxon_id in edges and 'visible_children' in edges[taxon_id]:
            children = edges[taxon_id]['visible_children']
            children = [str(child) for child in children]
        for child in children:
            children.extend(get_children_taxon(child, edges))
        return children

    @task()
    def update_possible_taxons():
        possible_taxons = json.load(open(f'{AIRFLOW_HOME}/dags/config_files/possible_taxons.json', 'r'))['taxons']
        hook = HttpHook(http_conn_id='NCBI-DATASETS')
        taxon_list = []
        for taxon in possible_taxons:
            response = hook.run(endpoint='taxonomy/filtered_subtree', data=json.dumps({'taxons': [taxon]}), headers={'Content-Type': 'application/json'})
            resp = response.json()
            edges = resp['edges']
            children = get_children_taxon(taxon, edges)
            taxon_list.extend(children)
        taxons = {
            'taxons': taxon_list
        }
        print(taxons)
        json.dump(taxons, open(f'/opt/airflow/temp/taxonomy_full/taxons.json', 'w'))


    @task()
    def get_data():
        hook = HttpHook(http_conn_id='NCBI-DATASETS')
        data = json.load(open('/opt/airflow/temp/taxonomy_full/taxons.json', 'r'))
        response = hook.run(endpoint='taxonomy', data=json.dumps(data))
        return response.json()


    @task()
    def save_data(ti=None):
        json.dump(ti.xcom_pull(task_ids='get_data'), open('/opt/airflow/temp/taxonomy_full/taxonomy.json', 'w'))

    save_to_s3 = LocalFilesystemToS3Operator(
        task_id='save_to_s3',
        aws_conn_id='AWS-PAWPRINT',
        filename='/opt/airflow/temp/taxonomy_full/taxonomy.json',
        dest_key='taxonomy/taxonomy/taxonomy_full.json',
        dest_bucket='geekfox-pawprint-raw',
        replace=True
    )

    @task(trigger_rule='all_done')
    def finish_job():
        shutil.rmtree('/opt/airflow/temp/taxonomy_full')

    init_job() >> update_possible_taxons() >> get_data() >> save_data() >> save_to_s3 >> finish_job()