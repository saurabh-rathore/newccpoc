# Use the official Asterisk image as a base
FROM asterisk/asterisk:20-certified

# Copy the custom configuration files into the container
COPY config/ari.conf /etc/asterisk/ari.conf
COPY config/extensions.conf /etc/asterisk/extensions.conf
COPY config/http.conf /etc/asterisk/http.conf
COPY config/pjsip.conf /etc/asterisk/pjsip.conf

# Asterisk runs as the 'asterisk' user. We need to set the ownership
# of the config files so that the user can read them.
RUN chown asterisk:asterisk /etc/asterisk/*.conf

# Expose the necessary ports:
# 8088 for ARI (HTTP)
# 5060 for SIP (UDP)
# 10000-10020 for RTP (UDP) - Media streams
EXPOSE 8088 5060/udp 10000-10020/udp
