FROM hwdsl2/ipsec-vpn-server:latest

COPY apply-fixes.sh /apply-fixes.sh
RUN chmod +x /apply-fixes.sh

CMD ["/apply-fixes.sh"]
