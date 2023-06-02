FROM exoscale/cli:1.69.0
COPY ./render.sh /acorn/scripts/render.sh
RUN mv /exo /usr/local/bin
ENTRYPOINT ["/acorn/scripts/render.sh"]