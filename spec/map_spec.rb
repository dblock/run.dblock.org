# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../_lib/map'

RSpec.describe Strava::Models::Map do
  subject(:map) { described_class.new(attributes) }

  let(:attributes) { { 'summary_polyline' => '_p~iF~ps|U_ulLnnqC_mqNvxq`@' } }
  let(:credentials) do
    {
      'GOOGLE_STATIC_MAPS_SERVER_API_KEY' => 'test-api-key',
      'GOOGLE_STATIC_MAPS_URL_SIGNING_SECRET' => 'vNIXE0xscrmjlyV-12Nj_BvUPaw='
    }
  end

  around do |example|
    original_environment = credentials.to_h { |name, _| [name, ENV[name]] }
    credentials.each { |name, value| ENV[name] = value }
    example.run
  ensure
    original_environment.each { |name, value| ENV[name] = value }
  end

  describe '#image_url' do
    it 'matches an independently calculated HMAC-SHA1 signature' do
      parameters = URI.decode_www_form(URI(map.image_url).query)

      expect(parameters.assoc('signature').last).to eq('eYVi7I9Q6qEORlZZd0OxyPW_hig=')
      expect(parameters.assoc('key').last).to eq('test-api-key')
      expect(parameters.assoc('path').last).to eq("enc:#{map.summary_polyline}")
      expect(parameters.select { |key, _| key == 'markers' }.map(&:last)).to eq([
        'color:yellow|label:S|38.5,-120.2',
        'color:green|label:F|43.252,-126.453'
      ])
      expect(map.image_url).not_to include(credentials.fetch('GOOGLE_STATIC_MAPS_URL_SIGNING_SECRET'))
    end

    %w[GOOGLE_STATIC_MAPS_SERVER_API_KEY GOOGLE_STATIC_MAPS_URL_SIGNING_SECRET].each do |name|
      [nil, ''].each do |missing|
        it "rejects #{missing.nil? ? 'missing' : 'empty'} #{name}" do
          ENV[name] = missing

          expect { map.image_url }.to raise_error(RuntimeError, "Missing #{name}")
        end
      end
    end
  end

  context 'without a route' do
    let(:attributes) { {} }

    before do
      credentials.each_key { |name| ENV.delete(name) }
    end

    it 'does not require credentials or download an image' do
      expect(HTTParty).not_to receive(:get)
      expect(map.image_url).to be_nil
      expect(map.png).to be_nil
    end
  end

  describe '#png' do
    let(:requests) { [] }
    let(:status) { 200 }
    let(:content_type) { 'image/png' }
    let(:body) { "\x89PNG\r\n\x1a\n".b }

    before do
      @signed_path = URI(map.image_url).request_uri
      @server = WEBrick::HTTPServer.new(
        BindAddress: '127.0.0.1', Port: 0,
        Logger: WEBrick::Log.new(File::NULL), AccessLog: []
      )
      @server.mount_proc('/maps/api/staticmap') do |request, response|
        requests << request
        response.status = status
        response['Content-Type'] = content_type
        response.body = body
      end
      @server_thread = Thread.new { @server.start }
      url = "http://127.0.0.1:#{@server.config[:Port]}#{@signed_path}"
      allow(map).to receive(:image_url).and_return(url)
    end

    after do
      @server&.shutdown
      @server_thread&.join
    end

    it 'downloads and caches the PNG without changing the signed URL or sending a referrer' do
      expect(map.png.b).to eq(body)
      expect(map.png.b).to eq(body)
      expect(requests.length).to eq(1)
      expect(requests.first.unparsed_uri).to eq(@signed_path)
      expect(requests.first['referer']).to be_nil
    end

    context 'when Google rejects the request' do
      let(:status) { 403 }
      let(:content_type) { 'text/plain' }
      let(:body) { 'Forbidden' }

      it 'raises instead of caching the error response as a PNG' do
        2.times do
          expect { map.png }.to raise_error(RuntimeError, 'Google Maps Static API request failed (HTTP 403)')
        end
        expect(requests.length).to eq(2)
      end
    end

    context 'when Google returns a non-PNG response' do
      let(:content_type) { 'text/html' }
      let(:body) { '<html>Error</html>' }

      it 'rejects the response' do
        expect { map.png }.to raise_error(RuntimeError, 'Google Maps Static API returned a non-PNG response')
      end
    end
  end
end
