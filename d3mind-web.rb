require 'tmpdir'
require 'json'
require 'securerandom'

require 'zip/zipfilesystem'
require 'nokogiri'
require 'cuba'
require 'cuba/render'


Cuba.plugin Cuba::Render
Cuba.use Rack::Static, root: 'static', urls: ["/css", "/js", "/data"]

def transform_topic(topic)
  obj = {
    'name' => topic.xpath('title/text()').text,
    'children' => topic.xpath('children/topics/topic').map { |t| transform_topic t }
  }
  return obj
end


Cuba.define do

  on get do
    on root do
      res.write view('index.html')
    end

    on 'mind/:id' do |id|
      res.write view('mind.html', id: id + '.json')
    end
  end

  on post do
    on 'upload' do
      tmpdir = Dir.mktmpdir
      Zip::ZipFile.open(req.params['file'][:tempfile].path) do |zip| 
        zip.extract(zip.find { |f| f.name == 'content.xml' },
                    tmpdir + '/content.xml')
      end
      xml = File.open(File.join(tmpdir, 'content.xml')) { |f|
                        Nokogiri::XML(f.read)
                      }
      xml.remove_namespaces!
      
      out_filename = SecureRandom.uuid 
      File.open(File.join('static/data/', out_filename + '.json'), 'w') { |f|
        f.write JSON.dump(transform_topic(xml.xpath('//sheet/topic')))

      }

      res.redirect "/mind/#{out_filename}"
    end
  end
  
end
