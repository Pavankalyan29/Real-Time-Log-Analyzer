import time
import logging
import os

log_dir = "/app/log"
os.makedirs(log_dir, exist_ok=True)
logging.basicConfig(
    filename=os.path.join(log_dir, "app.log"),
    level=logging.INFO,
    format="%(asctime)s - %(message)s"
)

while True:
    logging.info("Sample log message from app")
    time.sleep(5)
