#FROM rayproject/ray:latest-py311-cu121
#RUN pip install torch==2.1.1+cu121 torchvision==0.16.1+cu121 -f https://download.pytorch.org/whl/torch_stable.html
FROM rayproject/ray-ml:2.8.0-py310-cu118
RUN pip install fastapi uvicorn pydantic
WORKDIR /app
#ADD . .

# logging
ENV PYTHONUNBUFFERED=1
ENV UVICORN_LOG_LEVEL=error

#CMD python main.py

