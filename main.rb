require 'pp'
require 'open-uri'
require 'json'
require 'facets'

# Would you like to initialize a sequential (0) or parallel (1) download? (default: 1)
# How many concurrent downloads would you like to maintain? (default: 10)

# https://xkcd.com/info.0.json
# https://xkcd.com/614/info.0.json

class Downloader

  attr_accessor :comic_list, :comic_dir

  def initialize(comic_list, comic_dir)
    @comic_list, @comic_dir = comic_list.to_a, comic_dir
  end

  def start(thread_count = 10)

    # Create a thread safe queue.
    queue = Queue.new

    # Add work to the queue.
    @comic_list.each { |number| queue << number }

    # Create all threads.
    threads = thread_count.times.map do
      Thread.new { download(queue.pop) until queue.empty? }
    end

    # Start all threads.
    threads.each(&:join)

  end

  def download(number)
    begin

      puts "##{number} started downloading."

      # Fetch comic metadata for use within this script.
      meta = JSON.parse(open("https://xkcd.com/#{number}/info.0.json").read)

      # Make sure to always use HTTPS.
      image_uri = URI(meta['img'])
      image_uri.scheme = 'https'

      # Get file name and extension (`test.png`, `.png`, nope to `.jpeg`).
      f_title = File.basename(image_uri.path, '.*')
      f_extension = File.extname(image_uri.path)
      f_extension = f_extension.eql?('.jpeg') ? '.jpg' : f_extension

      # Create the new file title (`test.png` -> `test`).
      new_f_title = File.sanitize("#{number}_#{f_title}")

      # Save comic metadata for archival purposes.
      save_meta_file(meta, new_f_title)

      begin

        File.open("#{@comic_dir}/#{new_f_title}#{f_extension}", 'wb') do |file|
          file.puts(open(image_uri).read)
        end

      rescue OpenURI::HTTPError
        puts "Failed to download image ##{number} (#{f_title})."
        puts meta
      end

    rescue OpenURI::HTTPError
      puts "Could not find comic ##{number}."
    end
  end

  def save_meta_file(meta, f_title)
    f_contents = JSON.pretty_generate(meta)
    f_name = File.sanitize("#{f_title}.json")
    File.open("#{@comic_dir}/#{f_name}", 'wb') { |file| file.puts(f_contents) }
  end

end

Downloader.new(1607..1679, 'comics').start(5)
