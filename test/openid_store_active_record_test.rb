require 'test_helper'
require 'openid/store/nonce'

class OpenidStoreActiveRecordTest < MiniTest::Test

  # ============================================================================
  # TESTING SCENARIO
  # ============================================================================

  def setup
    prepare_scenario
    clean_tables
  end
  
  def teardown
    destroy_scenario
  end

  def prepare_scenario
    @store = OpenID::Store::ActiveRecord.new
    @@allowed_nonce = '0123456789abcdefghijklmnopqrst' +
      'uvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    @@allowed_handle = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ' +
      'RSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'
  end

  def clean_tables
    # super duper make sure talbes are empty
    OpenidAssociation.all.each { |ao| ao.destroy }
    OpenidNonce.all.each { |nonce| nonce.destroy }
  end

  def destroy_scenario
    @@allowed_handle = @@allowed_nonce = @store = nil
  end

  # ============================================================================
  # TESTS BELOW BROUGHT FROM THE ORIGINAL 'ruby-openid' (store) test suite
  # these methods test the association interactivity with a store object
  # ============================================================================

  def _gen_secret(n, chars=nil)
    OpenID::CryptUtil.random_string(n, chars)
  end

  def _gen_handle(n)
    OpenID::CryptUtil.random_string(n, @@allowed_handle)
  end

  def _gen_assoc(issued_at, lifetime=600)
    secret = _gen_secret(20)
    handle = _gen_handle(128)
    OpenID::Association.new(handle, secret, Time.now + issued_at, lifetime,
                            'HMAC-SHA1')
  end

  def _check_retrieve(url, handle=nil, expected=nil)
    ret_assoc = @store.get_association(url, handle)

    if expected.nil?
      assert_nil(ret_assoc)
    else
      %w[assoc_type handle issued lifetime secret].each do |prop|
        ex, actual = expected.send(prop), ret_assoc.send(prop)
        if ex.kind_of?(Time)
          ex, actual = ex.to_i, actual.to_i
        end
        assert_equal ex, actual, "#{prop} doesn't match"
      end
    end
  end

  def _check_remove(url, handle, expected)
    present = @store.remove_association(url, handle)
    assert_equal(expected, present)
  end

  def test_store
    server_url = "http://www.myopenid.com/openid"
    assoc = _gen_assoc(issued_at=0)

    # Make sure that a missing association returns no result
    _check_retrieve(server_url)

    # Check that after storage, getting returns the same result
    @store.store_association(server_url, assoc)
    _check_retrieve(server_url, nil, assoc)

    # more than once
    _check_retrieve(server_url, nil, assoc)

    # Storing more than once has no ill effect
    @store.store_association(server_url, assoc)
    _check_retrieve(server_url, nil, assoc)

    # Removing an association that does not exist returns not present
    _check_remove(server_url, assoc.handle + 'x', false)

    # Removing an association that does not exist returns not present
    _check_remove(server_url + 'x', assoc.handle, false)

    # Removing an association that is present returns present
    _check_remove(server_url, assoc.handle, true)

    # but not present on subsequent calls
    _check_remove(server_url, assoc.handle, false)

    # Put assoc back in the store
    @store.store_association(server_url, assoc)

    # More recent and expires after assoc
    assoc2 = _gen_assoc(issued_at=1)
    @store.store_association(server_url, assoc2)

    # After storing an association with a different handle, but the
    # same server_url, the handle with the later expiration is returned.
    _check_retrieve(server_url, nil, assoc2)

    # We can still retrieve the older association
    _check_retrieve(server_url, assoc.handle, assoc)

    # Plus we can retrieve the association with the later expiration
    # explicitly
    _check_retrieve(server_url, assoc2.handle, assoc2)

    # More recent, and expires earlier than assoc2 or assoc. Make sure
    # that we're picking the one with the latest issued date and not
    # taking into account the expiration.
    assoc3 = _gen_assoc(issued_at=2, lifetime=100)
    @store.store_association(server_url, assoc3)

    _check_retrieve(server_url, nil, assoc3)
    _check_retrieve(server_url, assoc.handle, assoc)
    _check_retrieve(server_url, assoc2.handle, assoc2)
    _check_retrieve(server_url, assoc3.handle, assoc3)

    _check_remove(server_url, assoc2.handle, true)

    _check_retrieve(server_url, nil, assoc3)
    _check_retrieve(server_url, assoc.handle, assoc)
    _check_retrieve(server_url, assoc2.handle, nil)
    _check_retrieve(server_url, assoc3.handle, assoc3)

    _check_remove(server_url, assoc2.handle, false)
    _check_remove(server_url, assoc3.handle, true)

    _check_retrieve(server_url, nil, assoc)
    _check_retrieve(server_url, assoc.handle, assoc)
    _check_retrieve(server_url, assoc2.handle, nil)
    _check_retrieve(server_url, assoc3.handle, nil)

    _check_remove(server_url, assoc2.handle, false)
    _check_remove(server_url, assoc.handle, true)
    _check_remove(server_url, assoc3.handle, false)

    _check_retrieve(server_url, nil, nil)
    _check_retrieve(server_url, assoc.handle, nil)
    _check_retrieve(server_url, assoc2.handle, nil)
    _check_retrieve(server_url, assoc3.handle, nil)

    _check_remove(server_url, assoc2.handle, false)
    _check_remove(server_url, assoc.handle, false)
    _check_remove(server_url, assoc3.handle, false)

    assocValid1 = _gen_assoc(-3600, 7200)
    assocValid2 = _gen_assoc(-5)
    assocExpired1 = _gen_assoc(-7200, 3600)
    assocExpired2 = _gen_assoc(-7200, 3600)

    @store.cleanup_associations
    @store.store_association(server_url + '1', assocValid1)
    @store.store_association(server_url + '1', assocExpired1)
    @store.store_association(server_url + '2', assocExpired2)
    @store.store_association(server_url + '3', assocValid2)

    cleaned = @store.cleanup_associations()
    assert_equal(2, cleaned, "cleaned up associations")
  end

  # ============================================================================
  # am including open id here because the nonce module is not being mocked
  # ============================================================================
  include OpenID

  # ============================================================================
  # TESTS BELOW BROUGHT FROM THE ORIGINAL 'ruby-openid' (store) test suite
  # these methods test the nonce interactivity with a store object
  # ============================================================================

  def _check_use_nonce(nonce, expected, server_url, msg='')
    stamp, salt = Nonce::split_nonce(nonce)
    actual = @store.use_nonce(server_url, stamp, salt)
    assert_equal(expected, actual, msg)
  end

  def test_nonce
    server_url = "http://www.myopenid.com/openid"
    [server_url, ''].each{|url|
      nonce1 = Nonce::mk_nonce

      _check_use_nonce(nonce1, true, url, "#{url}: nonce allowed by default")
      _check_use_nonce(nonce1, false, url, "#{url}: nonce not allowed twice")
      _check_use_nonce(nonce1, false, url, "#{url}: nonce not allowed third time")

      # old nonces shouldn't pass
      old_nonce = Nonce::mk_nonce(3600)
      _check_use_nonce(old_nonce, false, url, "Old nonce #{old_nonce.inspect} passed")

    }

    now = Time.now.to_i
    old_nonce1 = Nonce::mk_nonce(now - 20000)
    old_nonce2 = Nonce::mk_nonce(now - 10000)
    recent_nonce = Nonce::mk_nonce(now - 600)

    orig_skew = Nonce.skew
    Nonce.skew = 0
    Nonce.skew = 1000000
    ts, salt = Nonce::split_nonce(old_nonce1)
    assert(@store.use_nonce(server_url, ts, salt), "oldnonce1")
    ts, salt = Nonce::split_nonce(old_nonce2)
    assert(@store.use_nonce(server_url, ts, salt), "oldnonce2")
    ts, salt = Nonce::split_nonce(recent_nonce)
    assert(@store.use_nonce(server_url, ts, salt), "recent_nonce")


    Nonce.skew = 1000
    cleaned = @store.cleanup_nonces
    assert_equal(2, cleaned, "Cleaned #{cleaned} nonces")

    Nonce.skew = 100000
    ts, salt = Nonce::split_nonce(old_nonce1)
    assert(@store.use_nonce(server_url, ts, salt), "oldnonce1 after cleanup")
    ts, salt = Nonce::split_nonce(old_nonce2)
    assert(@store.use_nonce(server_url, ts, salt), "oldnonce2 after cleanup")
    ts, salt = Nonce::split_nonce(recent_nonce)
    assert(!@store.use_nonce(server_url, ts, salt), "recent_nonce after cleanup")

    Nonce.skew = orig_skew
  end

end