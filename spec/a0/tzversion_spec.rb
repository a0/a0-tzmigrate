# frozen_string_literal: true

def expect_eq_not_nil(value_a, value_b)
  expect(value_a).to eq(value_b)
  expect(value_a).not_to be nil
  expect(value_b).not_to be nil
end

RSpec.describe A0::TZMigration::TZVersion do
  it 'can load version index' do
    versions = A0::TZMigration::TZVersion.versions
    expect(versions.keys).to include('2013c', '2018e')
    expect(versions['2013c']['timezones']).to include('America/Santiago', 'Zulu')
  end

  it 'can load timezone index' do
    timezones = A0::TZMigration::TZVersion.timezones
    expect(timezones.keys).to include('America/Santiago', 'Zulu')
    expect(timezones['America/Santiago']['versions']).to include('2018c', '2018e')
  end

  it 'can get a tzversion release date' do
    tzversion = A0::TZMigration::TZVersion.new('America/Santiago', '2018e')
    released_at = tzversion.released_at
    expect(released_at).to eq('2018-05-01 23:42:51 -0700')
  end

  it 'can load an aliased tzversion and has the same data that the target timezone version' do
    tzversion_a = A0::TZMigration::TZVersion.new('America/Santiago', '2018e')
    tzversion_b = A0::TZMigration::TZVersion.new('Chile/Continental', '2018e')
    version_data_a = tzversion_a.version_data
    version_data_b = tzversion_b.version_data
    expect_eq_not_nil(version_data_a, version_data_b)
  end

  it 'throws error when loading an unknown version' do
    expect do
      tzversion_a = A0::TZMigration::TZVersion.new('America/Santiago', '1800a')
      tzversion_a.version_data
    end.to raise_error('Version 1800a not found for America/Santiago.')
  end

  it 'throws error when loading an unknown timezone' do
    expect do
      tzversion_a = A0::TZMigration::TZVersion.new('America/Santiagors', '2018e')
      tzversion_a.version_data
    end.to raise_error(RuntimeError)
  end

  it 'returns no changes for America/Santiago from version 2014i to 2014j' do
    tzversion_a = A0::TZMigration::TZVersion.new('America/Santiago', '2014i')
    tzversion_b = A0::TZMigration::TZVersion.new('America/Santiago', '2014j')
    changes = tzversion_a.changes(tzversion_b)
    expect(changes).to eq([])
  end

  it 'returns non empty changes for America/Santiago version 2016j to America/Punta_Arenas 2017a' do
    tzversion_a = A0::TZMigration::TZVersion.new('America/Santiago', '2016j')
    tzversion_b = A0::TZMigration::TZVersion.new('America/Punta_Arenas', '2017a')
    changes = tzversion_a.changes(tzversion_b)
    expect(changes.length).not_to eq(0)
  end

  it 'returns the expected changes for America/Caracas from version 2016c to 2016d' do
    tzversion_a = A0::TZMigration::TZVersion.new('America/Caracas', '2016c')
    tzversion_b = A0::TZMigration::TZVersion.new('America/Caracas', '2016d')
    changes = tzversion_a.changes(tzversion_b)
    first = changes.first

    expect(changes.length).to eq(1)
    expect(first[:off]).to eq(1800)
    expect(first[:ini]).to eq(Time.parse('2016-05-01T02:30:00-04:30').to_i)
    expect(first[:fin]).to eq(Float::INFINITY)
    expect(first[:ini_str]).to eq('2016-05-01 07:00:00 UTC')
    expect(first[:fin_str]).to eq('∞')
    expect(first[:off_str]).to eq('+00:30:00')
  end

  it 'returns the expected changes for versions with empty transitions like UTC' do
    tzversion_a = A0::TZMigration::TZVersion.new('UTC', '2013c')
    tzversion_b = A0::TZMigration::TZVersion.new('UTC', '2018e')
    changes = tzversion_a.changes(tzversion_b)
    expect(changes).to eq([])
  end

  it 'returns the expected changes between a version with empty transitions to an non empty one' do
    tzversion_a = A0::TZMigration::TZVersion.new('Africa/Abidjan', '2018e')
    tzversion_b = A0::TZMigration::TZVersion.new('UTC', '2018e')

    changes = tzversion_a.changes(tzversion_b)
    expected = [{ ini: -Float::INFINITY, fin: -1_830_383_032, off: 968, ini_str: '-∞', fin_str: '1912-01-01 00:16:08 UTC', off_str: '+00:16:08' }]
    expect(changes).to eq(expected)

    changes = tzversion_b.changes(tzversion_a)
    expected = [{ ini: -Float::INFINITY, fin: -1_830_383_032, off: -968, ini_str: '-∞', fin_str: '1912-01-01 00:16:08 UTC', off_str: '-00:16:08' }]
    expect(changes).to eq(expected)
  end

  def compare_inverse(zone_a, version_a, zone_b, version_b) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tzversion_a = A0::TZMigration::TZVersion.new(zone_a, version_a)
    tzversion_b = A0::TZMigration::TZVersion.new(zone_b, version_b)
    changes_ab = tzversion_a.changes(tzversion_b)
    changes_ba = tzversion_b.changes(tzversion_a)

    expect(changes_ab.length).to eq(changes_ba.length)

    changes_ab.each_with_index do |_item, index|
      item_a = changes_ab[index]
      item_b = changes_ba[index]

      expect_eq_not_nil(item_a[:ini], item_b[:ini])
      expect_eq_not_nil(item_a[:fin], item_b[:fin])
      expect_eq_not_nil(item_a[:off], -item_b[:off])
      expect_eq_not_nil(item_a[:ini_str], item_b[:ini_str])
      expect_eq_not_nil(item_a[:fin_str], item_b[:fin_str])
    end
  end

  versions = %w[2013c 2015a 2016a 2018e]
  versions.product(versions).each do |version_a, version_b|
    it "returns the inverse changes for America/Santiago between version #{version_a} and #{version_b}" do
      compare_inverse('America/Santiago', version_a, 'America/Santiago', version_b)
    end
  end

  it 'config base_url works as expected' do
    A0::TZMigration.configure do |config|
      config.base_url = 'http://foo'
    end
    expect do
      tz_version = A0::TZMigration::TZVersion.new('America/Santiagors', '2018e')
      tz_version.version_data
    end.to raise_error(StandardError)
    A0::TZMigration.configure do |config|
      config.base_url = 'https://a0.github.io/a0-tzmigration-ruby/data/'
    end
    expect do
      tz_version = A0::TZMigration::TZVersion.new('America/Santiagors', '2018e')
      tz_version.version_data
    end.to raise_error(StandardError)
    tz_version = A0::TZMigration::TZVersion.new('America/Santiago', '2018e')
    tz_version.version_data
  end
end
