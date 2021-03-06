require 'spec_helper'

require 'fog/aws/models/cdn/distributions'

describe Middleman::Cli::CloudFront do
  let(:cloudfront) { described_class.new }
  let(:options) do
    Middleman::CloudFront::Options.new(
      'access_key_id_123',
      'secret_access_key_123',
      'distribution_id_123',
      'filter_123',
      'after_build_123'
    )
  end
  let(:distribution) { double('distribution', invalidations: double('invalidations')) }

  describe '#invalidate' do
    before do
      allow_any_instance_of(Fog::CDN::AWS::Distributions).to receive(:get).and_return(distribution)
      allow(distribution.invalidations).to receive(:create) do
        double('invalidation', status: 'InProgress', wait_for: -> {})
      end
    end

    it 'gets the correct distribution' do
      allow(cloudfront).to receive(:list_files).and_return([])
      expect_any_instance_of(Fog::CDN::AWS::Distributions).to receive(:get).with('distribution_id_123')
      cloudfront.invalidate(options)
    end

    it 'normalizes paths' do
      files = %w(file directory/index.html)
      normalized_files = %w(/file /directory/index.html /directory/)
      allow(cloudfront).to receive(:list_files).and_return(files)
      expect(distribution.invalidations).to receive(:create).once.with(paths: normalized_files)
      cloudfront.invalidate(options)
    end

    context 'when the amount of files to invalidate is under the limit' do
      it 'divides them up in packages and creates one invalidation per package' do
        files = (1..Middleman::Cli::CloudFront::INVALIDATION_LIMIT).map { |i| "/file_#{i}" }
        allow(cloudfront).to receive(:list_files).and_return(files)
        expect(distribution.invalidations).to receive(:create).once.with(paths: files)
        cloudfront.invalidate(options)
      end
    end

    context 'when the amount of files to invalidate is over the limit' do
      it 'creates only one invalidation with all of them' do
        files = (1..(Middleman::Cli::CloudFront::INVALIDATION_LIMIT * 3)).map { |i| "/file_#{i}" }
        allow(cloudfront).to receive(:list_files).and_return(files)
        expect(distribution.invalidations).to receive(:create).once.with(paths: files[0, Middleman::Cli::CloudFront::INVALIDATION_LIMIT])
        expect(distribution.invalidations).to receive(:create).once.with(paths: files[Middleman::Cli::CloudFront::INVALIDATION_LIMIT, Middleman::Cli::CloudFront::INVALIDATION_LIMIT])
        expect(distribution.invalidations).to receive(:create).once.with(paths: files[Middleman::Cli::CloudFront::INVALIDATION_LIMIT * 2, Middleman::Cli::CloudFront::INVALIDATION_LIMIT])
        cloudfront.invalidate(options)
      end
    end

    context 'when files to invalidate are explicitly specified' do
      it 'uses them instead of the files in the build directory' do
        files = (1..3).map { |i| "/file_#{i}" }
        expect(distribution.invalidations).to receive(:create).once.with(paths: files)
        cloudfront.invalidate(options, files)
      end

      it "doesn't filter them" do
        files = (1..3).map { |i| "/file_#{i}" }
        options.filter = /filter that matches no files/
        expect(distribution.invalidations).to receive(:create).once.with(paths: files)
        cloudfront.invalidate(options, files)
      end

      it 'normalizes them' do
        files = %w(file directory/index.html)
        normalized_files = %w(/file /directory/index.html /directory/)
        expect(distribution.invalidations).to receive(:create).once.with(paths: normalized_files)
        cloudfront.invalidate(options, files)
      end
    end
  end
end
