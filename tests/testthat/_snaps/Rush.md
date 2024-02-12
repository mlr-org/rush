# worker can be started with script

    Code
      rush$create_worker_script(fun = fun)
    Output
      DEBUG (500): [rush] Pushing worker config to Redis
      DEBUG (500): [rush] Serializing worker configuration to 2384528 bytes
      INFO  (400): [rush] Start worker with:
      INFO  (400): [rush] Rscript -e 'rush::start_worker(network_id = 'test-rush', hostname = 'host', url = 'redis://127.0.0.1:6379')'
      INFO  (400): [rush] See ?rush::start_worker for more details.

