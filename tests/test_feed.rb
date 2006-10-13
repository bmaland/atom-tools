require "test/unit"

require "atom/feed"
require "webrick"

class AtomFeedTest < Test::Unit::TestCase
  def setup
    @http = Atom::HTTP.new
    @port = rand(1024) + 1024
    @s = WEBrick::HTTPServer.new :Port => @port, 
               :Logger => WEBrick::Log.new($stderr, WEBrick::Log::FATAL), 
               :AccessLog => []

    @test_feed =<<END
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Example Feed</title>
  <link href="http://example.org/"/>
  <updated>2003-12-13T18:30:02Z</updated>
  <author>
    <name>John Doe</name>
  </author>
  <id>urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6</id>

  <entry>
    <title>Atom-Powered Robots Run Amok</title>
    <link href="http://example.org/2003/12/13/atom03"/>
    <id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
    <updated>2003-12-13T18:30:02Z</updated>
    <summary>Some text.</summary>
  </entry>
</feed>
END
  end

  def test_merge
    feed1 = Atom::Feed.new
   
    feed1.title = "title"

    feed1.subtitle = "<br>"
    feed1.subtitle["type"] = "html"

    a = feed1.authors.new
    a.name = "test"

    feed2 = Atom::Feed.new

    feed = feed1.merge(feed2)

    assert_equal "text", feed.title["type"]
    assert_equal "title", feed.title.to_s 

    assert_equal "html", feed.subtitle["type"]
    assert_equal "<br>", feed.subtitle.to_s

    assert_equal 1, feed.authors.length
    assert_equal "test", feed.authors.first.name
  end

  def test_update
    @s.mount_proc("/") do |req,res|
      res.content_type = "application/atom+xml"
      res.body = @test_feed

      @s.stop
    end

    feed = Atom::Feed.new "http://localhost:#{@port}/"

    assert_equal nil, feed.title
    assert_equal nil, feed.id
    assert_equal [], feed.entries
    
    one_shot

    feed.update!

    assert_equal "Example Feed", feed.title.to_s
    assert_equal "urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6", feed.id
    assert_equal 1, feed.entries.length
  end

  def test_conditional_get
    @s.mount_proc("/") do |req,res|
      assert_nil req["If-None-Match"]
      assert_nil req["If-Modified-Since"]

      res["Etag"] = '"xyzzy"'
      res["Last-Modified"] = 'Wed, 15 Nov 1995 04:58:08 GMT'
      res.content_type = "application/atom+xml"
      res.body = @test_feed

      @s.stop
    end

    feed = Atom::Feed.new "http://localhost:#{@port}/"

    assert_equal 0, feed.entries.length
    assert_equal nil, feed.etag
    assert_equal nil, feed.last_modified

    one_shot

    feed.update!

    assert_equal 1, feed.entries.length
    assert_equal '"xyzzy"', feed.etag
    assert_equal 'Wed, 15 Nov 1995 04:58:08 GMT', feed.last_modified

    @s.mount_proc("/") do |req,res|
      assert_equal '"xyzzy"', req["If-None-Match"]
      assert_equal 'Wed, 15 Nov 1995 04:58:08 GMT', req["If-Modified-Since"]

      res.status = 304
      res.body = "this hasn't been modified"
      
      @s.stop
    end

    one_shot
    feed.update!

    assert_equal 1, feed.entries.length
  end

  def one_shot; Thread.new { @s.start }; end
end