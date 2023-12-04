import pandas as pd

def preprocess_taxonomy_table(df):
    return pd.json_normalize(df['taxonomy_nodes'].tolist())

def preprocess_genome_dataset_table(df):
    final_list = []
    for i in df['reports']:
        final_list.extend(i)

    return pd.json_normalize(final_list)