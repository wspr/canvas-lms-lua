--- Canvas LMS in Lua: Messaging
-- @submodule canvas

local canvas = {}

--- Message user table arguments.
-- The function `canvas:message_user` takes a table of arguments to define the message to send.
-- The table may consist of the following
-- @field canvasid The Canvas ID(s) of the recipient (reqd)
-- @field subject  The subject of the message to send
-- @field body     The body text of the message to send
-- @field course   The Canvas course ID to send from (defaults to defined course)
-- @field group_conversation   Whether a group message is sent (true, default) or multiple individual messages are sent (false) if multiple IDs are included
-- @field bulk_message   Default: |false|. Not sure what this does really but needs to be |true| for 100+ recipients and when |true| forces individual messages
-- @field force_new      Default: |false|. Not sure what this does really but when |true| forces individual messages
-- @table @{message_user_args}



--- Message a specific Canvas user.
-- @tparam bool send_check  Toggle whether to truly send the message or just to pretty print it to the screen
-- @tparam table msg        Table with entries to define message according to @{message_user_args}
function canvas:message_user(send_check,msg)

  if msg.subject==nil then
    error("Should not send a message without a subject.")
  end
  if msg.body==nil then
    error("Cannot send a message without a body.")
  end

  if msg.bulk_message == nil       then msg.bulk_message = false      end
  if msg.force_new == nil          then msg.force_new = false         end
  if msg.group_conversation == nil then msg.group_conversation = true end

  local opt = {
    subject = msg.subject,
    body = msg.body,
    group_conversation = msg.group_conversation,
    bulk_message = msg.bulk_message,
    force_new = msg.force_new,
    context_code="course_"..self.courseid,
  }

  local recip = msg.recipients or msg.canvasid
  if type(recip) ~= "table" then
    recip = {recip}
  end
  opt.recipients = recip

  if msg.attach then
    local attachments = msg.attach
    if type(attachments) ~= "table" then
      attachments = {attachments}
    end
    opt.attachment_ids = attachments
  end

  if msg.groupid and msg.courseid then
    error("Cannot send from both a COURSE and a GROUP")
  end
  if msg.groupid then
    opt.context_code="group_"..msg.groupid
  end
  if msg.courseid then
    opt.context_code="course_"..msg.courseid
  end

  local post_return
  if send_check then
    post_return = self:post("conversations",opt)
    if post_return.errors then
      error("POST error: "..post_return.errors[1].error_code..": "..post_return.errors[1].message)
    else
      print("=========== MESSAGE SENT ===========")
    end
  else
    print("=========== FACSIMILE OF UNSENT MESSAGE ===========")
  end
  print("Context: "..opt.context_code)
  print("Subject: "..opt.subject)
--  print("=====================================================")
--  print("Bulk message? "..(opt.bulk_message and "Y" or "N"))
--  print("Force new?    "..(opt.force_new and "Y" or "N"))
--  print("Group convo?  "..(opt.group_conversation and "Y" or "N"))
  print("=====================================================")
  print(opt.body)
  print("=================== END MESSAGE =====================")

  return post_return
end

return canvas

