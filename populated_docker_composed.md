services:
  clawdbot-gateway:
    build: .
    expose:
      - '18789'
    environment:
      CLAWDBOT_GATEWAY_TOKEN: '${CLAWDBOT_GATEWAY_TOKEN}'
      CLAWDBOT_STATE_DIR: /home/node/.clawdbot
      CLAWDBOT_WORKSPACE: /home/node/clawd
      GOOGLE_API_KEY: '${GOOGLE_API_KEY}'
      ANTHROPIC_API_KEY: '${ANTHROPIC_API_KEY}'
      COOLIFY_BRANCH: '"main"'
      COOLIFY_RESOURCE_UUID: lk40kg84os4kcgsggs0wkcck
      COOLIFY_CONTAINER_NAME: clawdbot-gateway-lk40kg84os4kcgsggs0wkcck-134731832202
      SERVICE_URL_CLAWDBOT_GATEWAY: 'https://clawdbot.apps.rjuro.com'
      SERVICE_FQDN_CLAWDBOT_GATEWAY: clawdbot.apps.rjuro.com
      COOLIFY_URL: 'https://clawdbot.apps.rjuro.com'
      COOLIFY_FQDN: clawdbot.apps.rjuro.com
      SERVICE_NAME_CLAWDBOT_GATEWAY: clawdbot-gateway
    volumes:
      - 'lk40kg84os4kcgsggs0wkcck_clawdbot-state:/home/node/.clawdbot'
      - 'lk40kg84os4kcgsggs0wkcck_clawdbot-workspace:/home/node/clawd'
    restart: unless-stopped
    networks:
      coolify: null
      default: null
      lk40kg84os4kcgsggs0wkcck: null
    labels:
      - traefik.enable=true
      - traefik.http.services.clawdbot.loadbalancer.server.port=18789
      - 'caddy_0.reverse_proxy={{upstreams 18789}}'
      - caddy_ingress_network=coolify
      - coolify.managed=true
      - coolify.version=4.0.0-beta.442
      - coolify.applicationId=23
      - coolify.type=application
      - coolify.name=clawdbot-gateway-lk40kg84os4kcgsggs0wkcck-134731832202
      - coolify.resourceName=r-juroclawed-bot-coolifymain-tg08gwskwgc0gc0wwcg80c4w
      - coolify.projectName=apps
      - coolify.serviceName=r-juroclawed-bot-coolifymain-tg08gwskwgc0gc0wwcg80c4w
      - coolify.environmentName=production
      - coolify.pullRequestId=0
      - traefik.enable=true
      - traefik.http.middlewares.gzip.compress=true
      - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
      - traefik.http.routers.http-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.entryPoints=http
      - traefik.http.routers.http-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.middlewares=redirect-to-https
      - 'traefik.http.routers.http-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.rule=Host(`clawdbot.apps.rjuro.com`) && PathPrefix(`/`)'
      - traefik.http.routers.https-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.entryPoints=https
      - traefik.http.routers.https-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.middlewares=gzip
      - 'traefik.http.routers.https-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.rule=Host(`clawdbot.apps.rjuro.com`) && PathPrefix(`/`)'
      - traefik.http.routers.https-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.tls.certresolver=letsencrypt
      - traefik.http.routers.https-0-lk40kg84os4kcgsggs0wkcck-clawdbot-gateway.tls=true
      - 'caddy_0.encode=zstd gzip'
      - 'caddy_0.handle_path.0_reverse_proxy={{upstreams}}'
      - 'caddy_0.handle_path=/*'
      - caddy_0.header=-Server
      - 'caddy_0.try_files={path} /index.html /index.php'
      - 'caddy_0=https://clawdbot.apps.rjuro.com'
      - caddy_ingress_network=lk40kg84os4kcgsggs0wkcck
    container_name: clawdbot-gateway-lk40kg84os4kcgsggs0wkcck-134731832202
volumes:
  lk40kg84os4kcgsggs0wkcck_clawdbot-state:
    name: lk40kg84os4kcgsggs0wkcck_clawdbot-state
  lk40kg84os4kcgsggs0wkcck_clawdbot-workspace:
    name: lk40kg84os4kcgsggs0wkcck_clawdbot-workspace
networks:
  coolify:
    external: true
  default: null
  lk40kg84os4kcgsggs0wkcck:
    name: lk40kg84os4kcgsggs0wkcck
    external: true
