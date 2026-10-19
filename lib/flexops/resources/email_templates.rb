# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Branded tracking email templates, one per tracking event. Answers are bare JSON (no
    # envelope); ids are GUID strings.
    #
    # Reads work with any API key or a user token. Writes (upsert, delete, preview) need a user
    # token (auth.login) or an API key granted the opt-in "email-templates:write" scope; a key
    # without it gets 403 API_KEY_SCOPE_REQUIRED.
    #
    # +eventType+ is the Gateway TrackingEmailEvent number: LabelCreated 0, InTransit 1,
    # OutForDelivery 2, Delivered 3, Exception 4, ReturnToSender 5.
    class EmailTemplates
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get(ws_path)
      end

      def get(template_id)
        @http.get("#{ws_path}/#{template_id}")
      end

      # Creates or replaces the template for request's +eventType+.
      #
      # request:: { eventType: (0-5), subjectTemplate: (<= 500 chars), htmlBodyTemplate:,
      #           isEnabled: (default true) }. Returns the template.
      def upsert(request)
        @http.put(ws_path, body: request)
      end

      # Returns nil (204).
      def delete(template_id)
        @http.delete("#{ws_path}/#{template_id}")
      end

      # Renders a draft with sample placeholder values. Returns { renderedSubject, renderedHtmlBody }.
      def preview(subject_template:, html_body_template:)
        @http.post("#{ws_path}/preview",
                   body: { subjectTemplate: subject_template, htmlBodyTemplate: html_body_template })
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}/email-templates"
      end
    end
  end
end
