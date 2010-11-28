class KeyQuincy
  def initialize
    @REPO_HTML = './watched.html'
    @REPO_DATA = './watched.json'
  end

  def download_repo_html
    return if File.exist?(@REPO_HTML)
    `curl https://github.com/popular/watched > #{@REPO_HTML}`
  end

  def extract_repo_data
    return if File.exist?(@REPO_DATA)
    require 'nokogiri'
    doc = Nokogiri::HTML(open(@REPO_HTML))
    usernames = doc.css('.repo td.owner').map {|e| e.text.strip}
    reponames = doc.css('.repo td.title').map {|e| e.text.strip}
    require 'json'
    repos = [usernames, reponames].transpose()
    json = JSON.pretty_generate({:repos => repos})
    File.open(@REPO_DATA, 'w') {|f| f.puts json}
  end

  def repo_data
    require 'json'
    @repo_data = JSON.parse(File.read(@REPO_DATA)) unless @repo_data
    @repo_data
  end

  def repo_owners
    unless @repo_owners
      @repo_owners = {}
      repo_data['repos'].each {|r| @repo_owners[r[1]] = r[0]}
    end
    @repo_owners
  end

  def repo_path(repo)
    "./repos/#{repo[1]}"
  end

  def download_repos
    repos = repo_data["repos"]
    repos.each_with_index do |repo, i|
      next if File.exist?(repo_path(repo))
      puts "Cloning repo #{i+1} of #{repos.length}"
      cmd = "git clone http://github.com/#{repo[0]}/#{repo[1]}.git"
      Dir.chdir "repos" do
        puts cmd
        `#{cmd}`
      end
    end
  end

  def database
    require 'couchrest'
    unless @database
      dbname = ARGV[0] || 'default'
      couchapprc = JSON.parse(File.read('app/.couchapprc'))
      dbconf = couchapprc['env'][dbname]['db'].rpartition('/')
      dbconf = {'server' => dbconf[0], 'database' => dbconf[-1]}
      server = CouchRest::Server.new dbconf['server']
      @database = server.database! dbconf['database']
    end
    @database
  end

  def copy_json
    require 'json'
    jsons = `find repos -iname '*.json'`.lines
    docs = []
    jsons.each do |path|
      value, parsed = nil, true
      fullpath = path.strip
      begin
        value = JSON.parse(File.read fullpath)
      rescue JSON::ParserError
        parsed = false
      end
      path = fullpath.split('/')[1..-1]
      doc = {
        "file"     => path[-1],
        "fullpath" => fullpath,
        "owner"    => repo_owners[path[0]],
        "parsed"   => parsed,
        "path"     => path[1..-2],
        "repo"     => path[0],
        "type"     => "json-file",
      }
      jj doc
      doc["value"] = value
      docs.push doc
    end

    puts database.to_s.sub(/:[^:@]+@/, ':xxx@')
    docs.each do |doc|
      puts "Saving #{doc["fullpath"]}..."
      begin
        database.save_doc(JSON.parse(doc.to_json))
      rescue RestClient::BadRequest => e
        puts e
      end
    end
  end

  def go!
    download_repo_html
    extract_repo_data
    download_repos
    copy_json
  end
end

if __FILE__ == $0
  KeyQuincy.new.go!
end
