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

  local recip = msg.recipients or msg.canvasid
  if type(recip)~="table" then
    recip = {recip}
  end
  local opt = {
    bulk_message = true,
    force_new = true,
    subject = msg.subject,
    body = msg.body,
    recipients = recip,
    group_conversation = true,
  }
  if msg.group_conversation ~= nil then
    opt.group_conversation = msg.group_conversation
  end
  if msg.attach then
    local attachments = msg.attach
    if type(attachments) ~= "table" then
      attachments = {attachments}
    end
    opt.attachment_ids = attachments
  end

  if msg.context then
    opt.context_code=msg.context
  elseif msg.course then
    opt.context_code="course_"..msg.course
  else
    opt.context_code="course_"..self.courseid
  end

  local post_return
  if send_check then
    post_return = self:post("conversations",opt)
    if post_return.errors then
      error("POST error: "..post_return.errors[1].error_code..": "..post_return.errors[1].message)
    else
      print("=========== FACSIMILE OF MESSAGE SENT ===========")
      print("Subject: "..msg.subject.."\n")
      print("=================================================")
      print(msg.body)
      print("=================== END MESSAGE =====================")
    end
  else
    print("=========== FACSIMILE OF MESSAGE NOT SENT ===========")
    print("Subject: "..msg.subject.."\n")
    print("=====================================================")
    print(msg.body)
    print("=================== END MESSAGE =====================")
  end

  return post_return
end

return canvas

