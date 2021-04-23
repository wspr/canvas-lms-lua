--- Canvas LMS in Lua: Messaging
-- @submodule canvas


canvas.message_group_wfile = function(self,send_check,msg)

  local function encode(str)
		str = string.gsub (str, "\n", "\r\n")
    str = string.gsub(str, "([^%w _ %- . ~])",
      function (c) return string.format ("%%%02X", string.byte(c)) end
    )
    str = string.gsub (str, " ", "+")
	  return str
	end


  local recipients="recipients[]=group_"..msg.canvasid
  local subject="subject="..msg.subject
  local body="body="..msg.body

  local attachfile = self:get("users/self/files","search_term="..msg.filestub)
  if #attachfile > 0 then
    local fileid = "attachment_ids[]="..attachfile[1].id
    local isgroup = "group_conversation=true"

    opt = recipients.."&"..subject.."&"..body.."&"..fileid.."&"..isgroup

    if send_check=="y" then
      self:post("conversations",encode(opt))
    else
      print("MESSAGE:")
      print(opt)
      print("AFTER ENCODING:")
      print(encode(opt))
      print("NOT SENT ACCORDING TO USER INSTRUCTIONS")
    end
  else
    error("No file found")
  end


end


canvas.message_user = function(self,send_check,msg)

  local function encode(str)
		str = string.gsub (str, "\n", "\r\n")
    str = string.gsub(str, "([^%w _ %- . ~])",
      function (c) return string.format ("%%%02X", string.byte(c)) end
    )
    str = string.gsub (str, " ", "+")
	  return str
	end

  local forcenew="bulk_message=true&force_new=true"
  local recipients="recipients[]="..msg.canvasid
  local subject="subject="..encode(msg.subject)
  local body="body="..encode(msg.body)

  opt = forcenew.."&"..recipients.."&"..subject.."&"..body

  if msg.context then
    opt = opt.."&context_code="..encode(msg.context)
  elseif msg.course then
    opt = opt.."&context_code=course_"..msg.course
  else
    opt = opt.."&context_code=course_"..self.courseid
  end

  if send_check then
    self:post("conversations",opt)
  else
    print(opt)
  end


end


