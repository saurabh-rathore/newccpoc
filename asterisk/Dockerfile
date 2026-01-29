# Use a free, community-maintained Asterisk image
FROM andrius/asterisk:20

# Copy the custom configuration files into the container
COPY config/ari.conf /etc/asterisk/ari.conf
COPY config/extensions.conf /etc/asterisk/extensions.conf
COPY config/pjsip.conf /etc/asterisk/pjsip.conf
COPY config/queues.conf /etc/asterisk/queues.conf

# The base image is configured to run as the 'asterisk' user.
# The default permissions for copied files (readable by all) are sufficient.
# The chown command is unnecessary and fails due to security constraints
# in the base image.

# Expose the necessary ports:
# 8088 for ARI (HTTP)
# 5060 for SIP (UDP)
# 10000-10020 for RTP (UDP) - Media streams
EXPOSE 8088 5060/udp 10000-10020/udp
