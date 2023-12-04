FROM public.ecr.aws/lambda/python:3.9

# Install dependencies
RUN pip uninstall dataclasses
COPY requirements.txt ./
RUN pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy function code
COPY data_quality.py ${LAMBDA_TASK_ROOT}/app.py
COPY pre_process.py ${LAMBDA_TASK_ROOT}/pre_process.py

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "app.lambda_handler" ]