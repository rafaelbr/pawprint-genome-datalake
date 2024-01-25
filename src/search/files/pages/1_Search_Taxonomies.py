import boto3
import pandas as pd
import awswrangler as wr
import streamlit as st
from st_aggrid import AgGrid, GridOptionsBuilder
from st_aggrid.shared import GridUpdateMode

boto3.setup_default_session(region_name='us-east-1')

def load_taxonomy_data():
    # Load data from S3
    df = wr.athena.read_sql_table(table='taxonomy', database='geekfox-pawprint-trusted', ctas_approach=False)
    return df

def load_taxonomy_counts():
    # Load data from S3
    df = wr.athena.read_sql_table(table='taxonomy_counts', database='geekfox-pawprint-trusted', ctas_approach=False)
    return df

def search_taxonomy_data(df, field, search_term):
    # Search data
    filter = None
    if field == 'Common Name':
        filter = df['common_name'].str.contains(search_term, case=False)
    elif field == 'Scientific Name':
        filter = df['scientific_name'].str.contains(search_term, case=False)
    df = df[filter]
    return df

def search_taxonomy_counts(df, tax_id):
    # Search data
    filter = df['tax_id'] == tax_id
    df = df[filter]
    return df

st.title('Search Taxonomy Data')
st.write('''
         Here we can search taxonomy data from Taxonomy Table.
            ''')


df = load_taxonomy_data()
counts_df = load_taxonomy_counts()
search_text = st.text_input('Search Taxonomy Data', 'Search...')
fields = ['Common Name', 'Scientific Name',]
field = st.selectbox('Search Field', fields)
if search_text:
    df = search_taxonomy_data(df, field, search_text)
    options = GridOptionsBuilder.from_dataframe(
        df, enableRowGroup=True, enableValue=True, enablePivot=True
    )

    options.configure_side_bar()

    options.configure_selection("single")
    selection = AgGrid(df,
                       enable_enterprise_modules=True,
                       gridOptions=options.build(),
                       update_mode=GridUpdateMode.MODEL_CHANGED,
                       allow_unsafe_jscode=True
                       )
    if selection['selected_rows']:
        counts = search_taxonomy_counts(counts_df, selection['selected_rows'][0]['tax_id'])
        st.write(counts)

