# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-24
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

# SCAN form replies as the Gateway writes them (ScanFormsController, ScanFormDto), from a fixture.
RSpec.describe "SCAN form replies" do
  let(:client) { create_client }
  let(:ws_path) { "#{BASE_URL}/api/workspaces/ws-test-123" }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:fixtures) { JSON.parse(File.read(File.expand_path("../fixtures/scan-forms.json", __dir__))) }

  def reply_with(method, url, body, status: 200)
    stub_request(method, url).to_return(status: status, body: body.to_json, headers: json_headers)
  end

  it "returns a created form with the fields the Gateway sends" do
    reply_with(:post, "#{ws_path}/scan-forms", fixtures["created"])

    form = client.scan_forms.create(trackingNumbers: %w[9400111899223456789014 9400111899223456789021],
                                    manifestDate: "2026-09-08")["data"]

    expect(form).to include(
      "scanFormId" => "3f2b8c1e9d4a4f6b8a7e2c5d1b0f9e88", "state" => FlexOps::ScanFormState::CREATED,
      "success" => true, "isSandbox" => false, "manifestNumber" => "9475711899560013735215",
      "manifestDate" => "2026-09-08T00:00:00", "createdAtUtc" => "2026-09-08T21:14:03.512Z",
      "packageCount" => 2, "originPostalCode" => "78701", "errorMessage" => nil,
      "trackingNumbers" => %w[9400111899223456789014 9400111899223456789021]
    )
    expect(FlexOps::ScanFormState.created?(form)).to be(true)
    expect(FlexOps::ScanFormState.pdf_bytes(form)[0, 5]).to eq("%PDF-")
  end

  it "lists sandbox forms without a PDF and operations whose outcome is unknown" do
    reply_with(:get, "#{ws_path}/scan-forms", fixtures["list"])

    sandbox, unknown = client.scan_forms.list["data"]

    expect(sandbox).to include("isSandbox" => true, "scanFormImage" => nil, "success" => true)
    expect(sandbox["manifestNumber"]).to start_with("SBOX")
    expect(FlexOps::ScanFormState.pdf_bytes(sandbox)).to be_nil
    expect(unknown).to include("state" => FlexOps::ScanFormState::OUTCOME_UNKNOWN, "success" => false,
                               "manifestNumber" => "", "packageCount" => 2)
    expect(FlexOps::ScanFormState.created?(unknown)).to be(false)
  end

  it "gets one form by its scanFormId" do
    reply_with(:get, "#{ws_path}/scan-forms/3f2b8c1e9d4a4f6b8a7e2c5d1b0f9e88", fixtures["created"])

    expect(client.scan_forms.get("3f2b8c1e9d4a4f6b8a7e2c5d1b0f9e88")["data"]["scanFormId"])
      .to eq("3f2b8c1e9d4a4f6b8a7e2c5d1b0f9e88")
  end

  %w[requestIdReused needsReview].each do |name|
    it "raises the Gateway 409 (#{name}) once, without retrying" do
      reply = fixtures[name]
      stub = reply_with(:post, "#{ws_path}/scan-forms", reply["body"], status: reply["status"])

      expect { client.scan_forms.create(trackingNumbers: ["9400"], manifestDate: "2026-09-08", requestId: "req-1") }
        .to raise_error(FlexOps::Error) { |error|
          expect(error.status).to eq(409)
          expect(error.message).to eq(reply["body"]["message"])
        }
      expect(stub).to have_been_requested.once
    end
  end
end
