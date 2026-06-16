# Another implementation - unused

import os

import redis
from redis.cluster import RedisCluster
import tornado.ioloop
import tornado.web


ENVIRONMENT = os.getenv("ENVIRONMENT", "DEV")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
REDIS_CLUSTER_MODE = os.getenv("REDIS_CLUSTER_MODE", "true").lower() in ["1", "true", "yes"]


def create_redis_client():
    if REDIS_CLUSTER_MODE:
        return RedisCluster(
            host=REDIS_HOST,
            port=REDIS_PORT,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
        )

    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        db=REDIS_DB,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_timeout=5,
    )


r = create_redis_client()
r.setnx("counter", 0)


class MainHandler(tornado.web.RequestHandler):
    def get(self):
        counter = r.incr("counter")
        self.render("index.html", environment=ENVIRONMENT, counter=counter)


class HealthHandler(tornado.web.RequestHandler):
    def get(self):
        self.set_status(200)
        self.write("ok")


def make_app():
    return tornado.web.Application(
        [
            (r"/", MainHandler),
            (r"/health", HealthHandler),
            (r"/static/(.*)", tornado.web.StaticFileHandler, {"path": "static"}),
        ],
        template_path="templates",
    )


if __name__ == "__main__":
    app = make_app()
    app.listen(PORT, address=HOST)
    print(f"App running: http://{HOST}:{PORT}", flush=True)
    tornado.ioloop.IOLoop.current().start()