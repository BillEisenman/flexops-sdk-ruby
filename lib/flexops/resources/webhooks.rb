# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "openssl"

module FlexOps
  module Resources
    class Webhooks
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get("#{ws_path}/webhooks")
      end

      def get(webhook_id)
        @http.get("#{ws_path}/webhooks/#{webhook_id}")
      end

      # Creates a webhook subscription.
      #
      # request:: a hash with +url+, optional +description+ and optional +events+, an
      #           array of FlexOps::WebhookEventType names (strings or symbols). +events+
      #           is sent as the Gateway's comma-separated +eventTypes+; leave it out to
      #           receive every event. A raw +eventTypes+ string ("*" or comma-separated
      #           names, no spaces) is sent unchanged instead.
      #
      # Raises ArgumentError, before any request, when +events+ is empty, is not an
      # array, names an event FlexOps does not send, or is given with +eventTypes+.
      def create(request)
        @http.post("#{ws_path}/webhooks", body: to_wire_request(request))
      end

      # Updates a webhook subscription. +data+ takes +url+, +description+, +status+
      # ("Active", "Paused" or "Disabled") and +events+, which replaces the subscribed
      # events and is sent as +eventTypes+. Raises ArgumentError as #create does.
      def update(webhook_id, data)
        @http.put("#{ws_path}/webhooks/#{webhook_id}", body: to_wire_request(data))
      end

      def delete(webhook_id)
        @http.delete("#{ws_path}/webhooks/#{webhook_id}")
      end

      def rotate_secret(webhook_id)
        @http.post("#{ws_path}/webhooks/#{webhook_id}/rotate-secret")
      end

      def list_delivery_logs(webhook_id)
        @http.get("#{ws_path}/webhooks/#{webhook_id}/deliveries")
      end

      # Headers FlexOps sends with every webhook delivery.
      EVENT_HEADER = "X-FlexOps-Event"         # event name; "test" for a test event
      EVENT_ID_HEADER = "X-FlexOps-Event-Id"
      TIMESTAMP_HEADER = "X-FlexOps-Timestamp" # Unix seconds, part of the signed string
      SIGNATURE_HEADER = "X-FlexOps-Signature" # "sha256=" + lowercase hex HMAC-SHA256
      DELIVERY_HEADER = "X-FlexOps-Delivery"

      # Seconds the X-FlexOps-Timestamp may be from now, either way.
      DEFAULT_TOLERANCE = 300

      SIGNATURE_PREFIX = "sha256="
      private_constant :SIGNATURE_PREFIX

      # Returns true when a FlexOps webhook delivery is authentic and fresh,
      # false otherwise. See verify_signature! for the arguments.
      def self.verify_signature(payload:, signature:, timestamp:, secret:, tolerance: DEFAULT_TOLERANCE, now: Time.now)
        verify_signature!(payload: payload, signature: signature, timestamp: timestamp,
                          secret: secret, tolerance: tolerance, now: now)
      rescue FlexOps::WebhookSignatureError
        false
      end

      # Verifies a FlexOps webhook delivery and returns true, or raises
      # FlexOps::WebhookSignatureError saying why.
      #
      # payload::   the raw request body exactly as received (verify before parsing it)
      # signature:: the X-FlexOps-Signature value, "sha256=<hex>" (bare hex is accepted)
      # timestamp:: the X-FlexOps-Timestamp value, Unix seconds
      # secret::    the subscription secret ("whsec_..."), used as-is
      # tolerance:: seconds the timestamp may be from +now+; non-positive keeps the default
      # now::       the current time (a Time or Unix seconds), for tests
      #
      # FlexOps signs "{timestamp}.{body}" with HMAC-SHA256; the comparison is
      # constant time.
      def self.verify_signature!(payload:, signature:, timestamp:, secret:, tolerance: DEFAULT_TOLERANCE, now: Time.now)
        if secret.nil? || secret.to_s.empty?
          raise FlexOps::WebhookSignatureError.new("Webhook secret is empty", code: "WEBHOOK_MISSING_SECRET")
        end
        if signature.nil? || signature.to_s.empty?
          raise FlexOps::WebhookSignatureError.new("Webhook signature header is missing", code: "WEBHOOK_MISSING_SIGNATURE")
        end

        timestamp = timestamp.to_s
        unless timestamp.match?(/\A\d+\z/)
          raise FlexOps::WebhookSignatureError.new("Webhook timestamp header is missing or not Unix seconds",
                                                   code: "WEBHOOK_INVALID_TIMESTAMP")
        end

        tolerance = DEFAULT_TOLERANCE unless tolerance.is_a?(Numeric) && tolerance.positive?
        if (now.to_i - timestamp.to_i).abs > tolerance
          raise FlexOps::WebhookSignatureError.new("Webhook timestamp is outside the tolerance",
                                                   code: "WEBHOOK_TIMESTAMP_OUTSIDE_TOLERANCE")
        end

        signed = "#{timestamp}.".b << payload.to_s.b
        expected = OpenSSL::HMAC.hexdigest("SHA256", secret.to_s, signed)
        received = signature.to_s.delete_prefix(SIGNATURE_PREFIX).downcase
        # OpenSSL.secure_compare hashes both sides first, so unequal lengths are safe.
        unless OpenSSL.secure_compare(expected, received)
          raise FlexOps::WebhookSignatureError.new("Webhook signature does not match", code: "WEBHOOK_SIGNATURE_MISMATCH")
        end

        true
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end

      # The Gateway reads a comma-separated eventTypes string, ignores an events field
      # (subscribing to every event) and matches each name exactly, so a name it never
      # sends would leave the subscription silent; it is refused here instead.
      def to_wire_request(request)
        return request unless request.is_a?(Hash)

        events_key = [:events, "events"].find { |key| request.key?(key) }
        return request if events_key.nil?

        body = request.reject { |key, _| key == events_key }
        events = request[events_key]
        return body if events.nil?

        if [:eventTypes, "eventTypes"].any? { |key| body.key?(key) }
          raise ArgumentError, "Pass events or eventTypes, not both."
        end

        body.merge(eventTypes: to_event_types(events))
      end

      def to_event_types(events)
        unless events.is_a?(Array)
          raise ArgumentError, "events must be an array of event names, not #{events.class}."
        end
        if events.empty?
          raise ArgumentError, "events must name at least one event; leave it out to receive every event."
        end

        names = events.map { |event| event.is_a?(String) || event.is_a?(Symbol) ? event.to_s : event.inspect }.uniq
        unknown = names - FlexOps::WebhookEventType::ALL
        unless unknown.empty?
          raise ArgumentError, "Unknown webhook event: #{unknown.join(", ")}. " \
                               "FlexOps sends #{FlexOps::WebhookEventType::ALL.join(", ")}."
        end

        names.join(",")
      end
    end
  end
end
