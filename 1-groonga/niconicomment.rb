# -*- coding: utf-8 -*-
require 'groonga'
require 'json'

Encoding.default_external = 'utf-8'
Groonga::Context.default_options = {:encoding => :utf8}

begin
  Groonga::Database.open("./db/grn")
rescue
  Groonga::Database.create(:path => "./db/grn")
end

# schema定義

Groonga::Schema.create_table("Tags", :type => :patricia_trie)

Groonga::Schema.create_table("Videos", :type => :hash) do |table|
  table.short_text("title")
  table.text("description")
  table.short_text("thumbnail_url")
  table.time("upload_time")
  table.uint32("length")
  table.short_text("movie_type")
  table.uint32("size_high")
  table.uint32("size_low")
  table.uint64("view_counter")
  table.uint64("comment_counter")
  table.uint64("mylist_counter")
  table.reference("taglist", "Tags", :type => :vector)
  table.reference("locked_taglist", "Tags", :type => :vector)
  table.reference("category_taglist", "Tags", :type => :vector)
end

Groonga::Schema.create_table("Comments", :type => :hash) do |table|
  table.reference("video", "Videos")
  table.time("date")
  table.uint64("no")
  table.uint64("vpos")
  table.short_text("comment")
  table.short_text("command")
end

# 語彙表作成

Groonga::Schema.create_table("CommentTerms",
                             :type => :patricia_trie,
                             :normalizer => :NormalizerAuto,
                             :default_tokenizer => "TokenBigram"   # TokenMecabもあるよ
                             ) do |table|
  table.index("Comments.comment")
end


cmd = ARGV[0]
if !cmd.nil?
  Dir.glob(File.join(cmd, "video/*.dat")) do |path|
    File.open(path).each do |line|
      j = JSON.parse(line)
      Groonga["Videos"].add(j["video_id"], :title => j["title"],
                            :description => j["description"],
                            :thumbnail_url => j["thumbnail_url"],
                            :upload_time => j["upload_time"],
                            :length => j["length"],
                            :movie_type => j["movie_type"],
                            :size_high => j["size_high"],
                            :size_low => j["size_low"],
                            :view_counter => j["view_counter"],
                            :comment_counter => j["comment_counter"],
                            :mylist_counter => j["mylist_counter"],
                            :taglist => j["tags"].map{|x| x["tag"]},
                            :locked_taglist => j["tags"].select{|x| x["lock"] == 1}.map{|x| x["tag"]},
                            :category_taglist => j["tags"].select{|x| x["category"] == 1}.map{|x| x["tag"]}
                            )
    end
  end

  Dir.glob(File.join(cmd, "thread/**/sm*.dat")) do |path|
    videoid = "sm" + Integer(path.match(/(\d+)\/sm(\d+).dat$/).captures.join, 10).to_s
    puts videoid
    File.open(path).each do |line|
      j = JSON.parse(line)
      primary_id = %Q!#{videoid}/#{j["no"]}!
      Groonga["Comments"].add(primary_id, :video => videoid,
                              :date => j["date"],
                              :no => j["no"],
                              :vpos => j["vpos"],
                              :comment => j["comment"],
                              :command => j["command"]
                              )
    end
  end
end
