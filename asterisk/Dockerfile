# Use a free, community-maintained Asterisk image
FROM andrius/asterisk:20

# Copy the custom configuration files into the container
COPY config/ari.conf /etc/asterisk/ari.conf
COPY config/extensions.conf /etc/asterisk/extensions.conf
COPY config/pjsip.conf /etc/asterisk/pjsip.conf
COPY config/queues.conf /etc/asterisk/queues.conf

# Switch to root to change ownership of the config files
USER root

# Asterisk runs as the 'asterisk' user. We need to set the ownership
# of the config files so that the user can read them.
RUN chown asterisk:asterisk /etc/asterisk/*.conf

# Switch back to the non-root user for security
USER asterisk

# Expose the necessary ports:
# 8088 for ARI (HTTP)
# 5060 for SIP (UDP)
# 10000-10020 for RTP (UDP) - Media streams
EXPOSE 8088 5060/udp 10000-10020/udp
