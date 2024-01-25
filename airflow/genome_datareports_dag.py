import json
import os
import shutil
from datetime import datetime

from airflow import DAG
from airflow.decorators import task
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.http.hooks.http import HttpHook

AIRFLOW_HOME = '/opt/airflow/dags/repo'

with DAG(
    dag_id='genome_datareports',
    tags=['genome', 'incremental-load', 'daily'],
    start_date=datetime(2023, 11, 21),
    schedule_interval='@daily',
    catchup=False
):
    @task()
    def init_job():
        os.mkdir('/opt/airflow/temp/genome_datareports')
        os.mkdir('/opt/airflow/temp/genome_datareports/taxons')
        os.mkdir('/opt/airflow/temp/genome_datareports/dataset_reports')

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

        #split final taxon files
        max_taxons = 100
        for i in range(0, len(taxon_list), max_taxons):
            taxons = {
                'taxons': taxon_list[i:i+max_taxons]
            }
            json.dump(taxons, open(f'/opt/airflow/temp/genome_datareports/taxons/taxons_{i}.json', 'w'))


    @task()
    def load_data():
        hook = HttpHook(http_conn_id='NCBI-DATASETS')
        i = 0
        for file in os.listdir('/opt/airflow/temp/genome_datareports/taxons'):
            data = json.load(open(f'/opt/airflow/temp/genome_datareports/taxons/{file}', 'r'))
            print(data)
            while True:
                i += 1
                response = hook.run(endpoint='genome/dataset_report', data=json.dumps(data))
                resp = response.json()
                json.dump(resp, open(f'/opt/airflow/temp/genome_datareports/dataset_reports/datareport_{i}.json', 'w'))
                if 'next_page_token' not in resp:
                    break
                data['page_token'] = resp['next_page_token']

    @task()
    def transfer_files():
        hook = S3Hook(aws_conn_id='AWS-PAWPRINT')
        for file in os.listdir('/opt/airflow/temp/genome_datareports/dataset_reports'):
            hook.load_file(
                filename=f'/opt/airflow/temp/genome_datareports/dataset_reports/{file}',
                key=f"pending/genome/dataset_report/date={ datetime.now().strftime('%Y-%m-%d') }/{file}",
                bucket_name='geekfox-pawprint-raw',
                replace=True
            )

    @task(trigger_rule='all_done')
    def finish_job():
        shutil.rmtree('/opt/airflow/temp/genome_datareports')

    init_job() >> update_possible_taxons() >> load_data() >> transfer_files() >> finish_job()

