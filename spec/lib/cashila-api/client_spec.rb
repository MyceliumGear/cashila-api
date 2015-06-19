require 'cashila-api'

RSpec.describe CashilaAPI::Client do

  it "is initializable" do
    expect {
      described_class.new
    }.to raise_error(ArgumentError)

    @client = described_class.new(client_id: '123')
    expect(@client.client_id).to eq '123'
    expect(@client.secret).to eq nil
    expect(@client.token).to eq nil
    expect(@client.url).to eq 'https://cashila-staging.com'

    @client = described_class.new(client_id: '123', secret: 'a', token: 'b', url: 'http://example.com')
    expect(@client.secret).to eq 'a'
    expect(@client.token).to eq 'b'
    expect(@client.url).to eq 'http://example.com'
  end

  it "constructs connection" do
    @client     = described_class.new(client_id: '123')
    @connection = @client.connection
    expect(@connection.url_prefix.to_s).to eq CashilaAPI::TEST_URL + '/'
    expect(@connection.headers).to eq('Content-Type' => 'application/json', 'API-Client' => '123', 'User-Agent' => 'Faraday v0.9.1')
  end

  it "constructs signed connection" do
    @client = described_class.new(client_id: '123')
    expect {
      @connection = @client.connection(sign: true)
    }.to raise_error(described_class::InvalidCredentials)

    @client     = described_class.new(client_id: '123', secret: 'a', token: 'b')
    @connection = @client.connection(sign: true)
  end

  describe "API wrapper" do

    before :each do
      @client = described_class.new(
        client_id: '92c91f99-c157-41cd-864b-1b675bfcf919',
        url:       'https://cashila-staging.com',
      )
    end

    it "does not allows requests" do
      expect {
        @client.request_signup
      }.to raise_error(VCR::Errors::UnhandledHTTPRequestError)
    end

    it "requests signup" do
      VCR.use_cassette 'cashila_request_signup' do
        @result = @client.request_signup
      end
      expect(@result.keys.sort).to eq %w{secret token}
    end

    it "requires credentials" do
      expect {
        @client.verification_status
      }.to raise_error(described_class::InvalidCredentials)
    end

    context "with credentials" do

      before :each do
        @client.token  = '40b0c81d-626e-4cf6-af79-75fb92800f32'
        @client.secret = 'ldUBiJqbXFYK63iC6bM48Ok2g83dqDtSvCyTL94QHPGmhpMzmmNKcyQGacjBnkTt1cby4p3yXSrqR33LLen5hw=='
      end

      it "syncs account" do
        details = {
          first_name:   'Example',
          last_name:    'Xample',
          address:      'somewhere',
          postal_code:  '000000',
          city:         'Vilnius',
          country_code: 'LT',
        }
        VCR.use_cassette 'cashila_sync_account' do
          @result = @client.sync_account(email: 'alerticus@gmail.com', details: details)
        end
        expect(@result).to eq({})

        VCR.use_cassette 'cashila_verification_status' do
          @result = @client.verification_status
        end
        expect(@result).to eq("status" => "pending", "first_name" => "Example", "last_name" => "Xample", "address" => "somewhere", "city" => "Vilnius", "postal_code" => "000000", "country_code" => "LT", "gov-id-front" => {"present" => false}, "gov-id-back" => {"present" => false}, "residence" => {"present" => false})
      end

      it "uploads docs" do
        doc = File.read('spec/fixtures/multipass.jpg')
        VCR.use_cassette 'cashila_upload_docs' do
          @result = @client.upload_docs(
            :'gov-id-front' => doc,
            :'gov-id-back'  => doc,
            :residence      => doc,
          )
        end
        expect(@result).to eq([{}, {}, {}])

        VCR.use_cassette 'cashila_verification_status_with_docs' do
          @result = @client.verification_status
        end
        expect(@result).to eq("status" => "pending", "first_name" => "Example", "last_name" => "Xample", "address" => "somewhere", "city" => "Vilnius", "postal_code" => "000000", "country_code" => "LT", "gov-id-front" => {"present" => true, "approved" => false}, "gov-id-back" => {"present" => true, "approved" => false}, "residence" => {"present" => true, "approved" => false})
      end

      it "syncs recipient" do
        details = {
          name:         'Example Xample',
          address:      'somewhere',
          postal_code:  '000000',
          city:         'Vilnius',
          country_code: 'LT',
          bic:          'BPHKPLPK',
          iban:         'LT121000011101001000',
        }
        id      = 'af1cfdf9-be92-46a4-b6b0-a606a86b1e7a'
        VCR.use_cassette 'cashila_create_recipient' do
          @result = @client.sync_recipient(details)
        end
        expect(@result).to eq id

        details[:id]   = id
        details[:name] = 'Rena Med'
        VCR.use_cassette 'cashila_update_recipient' do
          @result = @client.sync_recipient(details)
        end
        expect(@result).to eq id

        VCR.use_cassette 'cashila_get_recipient' do
          @result = @client.get_recipient(id)
        end
        expect(@result).to eq("id" => id, "name" => "Rena Med", "address" => "somewhere", "postal_code" => "000000", "city" => "Vilnius", "country_code" => "LT", "country_name" => "Lithuania", "last_used" => "2015-06-18T17:49:29+0000")
      end

      it "creates billpay" do
        VCR.use_cassette 'cashila_create_billpay' do
          @result = @client.create_billpay(amount: 1.21, recipient_id: 'af1cfdf9-be92-46a4-b6b0-a606a86b1e7a')
        end
        expect(@result).to eq("id" => "dce801a6-2a01-4b37-b77b-5e609724b8be", "status" => "pending", "recipient" => {"name" => "Rena Med", "address" => "somewhere", "postal_code" => "000000", "city" => "Vilnius", "country_code" => "LT", "country_name" => "Lithuania"}, "payment" => {"iban" => "LT12 1000 0111 0100 1000 ", "bic" => "BPHKPLPK", "amount" => 1.21, "currency" => "EUR"}, "details" => {"created_at" => "2015-06-19T09:44:52+0000", "updated_at" => "2015-06-19T09:44:52+0000", "fee" => 0.02, "exchange_rate" => 217.22358606, "amount_deposited" => "0", "amount_to_deposit" => "0.00566236", "total_amount" => "0.00566236", "wallet_url" => "bitcoin:mszb3RpMpBDrk78eEQqBWVvH3AHnPgYkoG?amount=0.00566236", "valid_until" => "2015-06-19T10:14:52+0000", "address" => "mszb3RpMpBDrk78eEQqBWVvH3AHnPgYkoG"})
      end
    end
  end
end
