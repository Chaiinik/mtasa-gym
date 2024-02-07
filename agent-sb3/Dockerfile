FROM pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime
RUN pip install stable-baselines3
RUN pip install fastapi pydantic uvicorn
RUN pip install rtgym==0.13

#WORKDIR /app/rtgym
#ADD rtgym .
#RUN pip install -e .

WORKDIR /app
ADD . .

# Disable logging
ENV PYTHONUNBUFFERED=1
ENV UVICORN_LOG_LEVEL=error

CMD ["uvicorn", "main-goal:app", "--host", "0.0.0.0", "--port", "8000"]
#CMD python main.py

