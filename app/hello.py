import os
from sys import exit

import redis
from redis.cluster import RedisCluster
from redis.exceptions import ConnectionError, RedisError

import tornado.ioloop
import tornado.web


environment = os.getenv("ENVIRONMENT")
host = os.getenv("HOST")
port = int(os.getenv("PORT"))

redis_host = os.getenv("REDIS_HOST")
redis_port = int(os.getenv("REDIS_PORT"))
redis_db = int(os.getenv("REDIS_DB"))
redis_cluster_mode = os.getenv("REDIS_CLUSTER_MODE", "false").lower() in [
    "1",
    "true",
    "yes",
]


try:
    if redis_cluster_mode:
        r = RedisCluster(
            host=redis_host,
            port=redis_port,
            decode_responses=True,
        )
    else:
        r = redis.Redis(
            host=redis_host,
            port=redis_port,
            db=redis_db,
            decode_responses=True,
        )

    # Keep this if you want the original behavior:
    # r.set("counter", 0)

    # Better for Kubernetes: do not reset counter every time a pod restarts.
    r.setnx("counter", 0)

except (ConnectionError, RedisError) as e:
    print(f"Redis server isn't running or is not reachable. Exiting... {e}")
    exit()


class MainHandler(tornado.web.RequestHandler):
    def get(self):
        self.render(
            "index.html",
            dict={"environment": environment, "counter": r.incr("counter", 1)},
        )


class HealthHandler(tornado.web.RequestHandler):
    def get(self):
        self.set_status(200)
        self.write("ok")


class Application(tornado.web.Application):
    def __init__(self):
        handlers = [
            (r"/", MainHandler),
            (r"/health", HealthHandler),
        ]

        settings = {
            "template_path": os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "templates"
            ),
            "static_path": os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "static"
            ),
        }

        tornado.web.Application.__init__(self, handlers, **settings)


if __name__ == "__main__":
    app = Application()
    app.listen(port, address=host)
    print(f"App running: http://{host}:{port}")
    tornado.ioloop.IOLoop.current().start()