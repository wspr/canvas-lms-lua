--- Canvas LMS in Lua: Discussion Boards
-- @submodule canvas

local pretty = require("pl.pretty")
local canvas = {}

--- Get discussion topics and store their metadata and IDs.
function canvas:get_discussion_topics()

  local discuss_topics = self:get_paginated(true,self.course_prefix.."discussion_topics")

  local hash = {}
  for _,vv in ipairs(discuss_topics) do
    hash[vv.title] = vv.id
  end
  self.discussion_topics = discuss_topics
  self.discussion_topic_ids = hash

end


--- Create/edit up discussion topics.
-- Generally I like to set up all discussion topics once at the beginning of semester.
-- Due to interface confusion I also prefer to keep a "frozen" list of discussion topics and
-- not allow students to create their own.
-- Defaults to published and nested.
-- TODO: logical week conversion for delayed posting.
-- @tparam table args Table of tables with REST arguments (see [Canvas API documentation](https://erau.instructure.com/doc/api/discussion_topics.html#method.discussion_topics.create)).
-- Usage:
--     canvas:setup_discussion_topics{
--       { title = "Course Q&A" , pinned = true },
--       { title = "Assign 1 discussion" },
--       { title = "Assign 2 discussion" },
--     }
function canvas:setup_discussion_topics(args)

  self:print("# Setting up discussion topics")

  self:print("Disable students from creating their own topics?")
  self:print("Type y to do so:")
  if io.read() == "y" then
    self:put(self.course_prefix.."settings/",{allow_student_discussion_topics=false})
  end

  local discussion_topics = {}
  local titles_lookup = {}
  for ii,vv in ipairs(args) do
    discussion_topics[ii] = vv
    discussion_topics[ii].published = discussion_topics[ii].published or true
    discussion_topics[ii].discussion_type = discussion_topics[ii].discussion_type or
                                            self.defaults.discussion.discussion_type
    titles_lookup[vv.title] = true
  end

  if self.discussion_topics == nil then
    self:get_discussion_topics()
  end

  for _,vv in ipairs(discussion_topics) do
    if self.discussion_topic_ids[vv.title] then
      self:put(self.course_prefix.."discussion_topics/"..self.discussion_topic_ids[vv.title],vv)
    else
      local xx = self:post(self.course_prefix.."discussion_topics",vv)
      self.discussion_topic_ids[xx.title] = xx.id
    end
  end

  for tt,id in pairs(self.discussion_topic_ids) do
    if not(titles_lookup[tt]) then
      self:print("Discussion topic currently exists but not specified: '"..tt.. "'. Delete it?")
      self:print("Type y to do so:")
      if io.read() == "y" then
        self:delete(self.course_prefix.."discussion_topics/"..id)
      end
    end
  end

  self:print("## DISCUSSION TOPICS")
  pretty.dump(self.discussion_topic_ids)

end


return canvas

