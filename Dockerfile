FROM n8nio/n8n:latest

USER root

WORKDIR /home/node/packages/cli

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]