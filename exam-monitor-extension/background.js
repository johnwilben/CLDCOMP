const GSHEET="https://script.google.com/macros/s/AKfycbxZk6OvY_lUv65F-yzqcST7Udp1uSpRPDmeGCn2fzjvtIsY3V-7z85ED0I4uC_Rp0UIqA/exec";

const BLOCKED_DOMAINS=["chat.openai.com","chatgpt.com","claude.ai","gemini.google.com","copilot.microsoft.com","bard.google.com","perplexity.ai","poe.com","you.com","phind.com","huggingface.co/chat"];
const ALLOWED_DOMAINS=["console.aws.amazon.com","github.com","raw.githubusercontent.com","amazonaws.com","docs.google.com"];

let studentName="";
let examActive=false;
let violations=[];
let tabLog=[];

// Load state
chrome.storage.local.get(["studentName","examActive","violations","tabLog"],r=>{
  studentName=r.studentName||"";
  examActive=r.examActive||false;
  violations=r.violations||[];
  tabLog=r.tabLog||[];
});

function save(){
  chrome.storage.local.set({studentName,examActive,violations,tabLog});
}

function ts(){return new Date().toLocaleString("en-PH",{year:"numeric",month:"short",day:"numeric",hour:"2-digit",minute:"2-digit",second:"2-digit"});}

function getDomain(url){
  try{return new URL(url).hostname;}catch(e){return"";}
}

function isBlocked(url){
  const d=getDomain(url);
  return BLOCKED_DOMAINS.some(b=>d.includes(b));
}

function isAllowed(url){
  const d=getDomain(url);
  return ALLOWED_DOMAINS.some(a=>d.includes(a));
}

function logViolation(type,url){
  const entry={type,url:getDomain(url),time:ts(),full:url.substring(0,100)};
  violations.push(entry);
  tabLog.push(entry);
  save();
  sendToSheet(entry);
}

function logTab(url){
  const entry={type:"tab_visit",url:getDomain(url),time:ts()};
  tabLog.push(entry);
  save();
}

async function sendToSheet(entry){
  if(!studentName)return;
  try{
    await fetch(GSHEET,{
      method:"POST",
      headers:{"Content-Type":"application/json"},
      body:JSON.stringify({
        studentName:studentName,
        instanceId:"ext-"+studentName.replace(/\s/g,"_"),
        rdsEndpoint:"",
        set:"MONITOR",
        score:violations.length+"_violations",
        p1:entry.type,
        p2:entry.url,
        p3:entry.full||"",
        p4:"",
        p5:"",
        appInstalled:"",
        sgCheck:"",
        timestamp:entry.time,
        privateIp:"",
        accountId:""
      })
    });
  }catch(e){}
}

// Monitor tab updates
chrome.tabs.onUpdated.addListener((tabId,changeInfo,tab)=>{
  if(!examActive||!changeInfo.url)return;
  const url=changeInfo.url;
  
  if(isBlocked(url)){
    logViolation("🚨 AI_TOOL_DETECTED",url);
    // Show warning
    chrome.tabs.sendMessage(tabId,{action:"warn",msg:"⚠️ AI tool detected! This has been logged."}).catch(()=>{});
  }else if(!isAllowed(url)){
    logTab(url);
  }
});

// Monitor tab activation (switching)
chrome.tabs.onActivated.addListener(async(activeInfo)=>{
  if(!examActive)return;
  try{
    const tab=await chrome.tabs.get(activeInfo.tabId);
    if(tab.url&&isBlocked(tab.url)){
      logViolation("🚨 AI_TAB_SWITCHED_TO",tab.url);
    }
  }catch(e){}
});

// Monitor new tabs
chrome.tabs.onCreated.addListener(async(tab)=>{
  if(!examActive)return;
  // Small delay to get URL
  setTimeout(async()=>{
    try{
      const t=await chrome.tabs.get(tab.id);
      if(t.url&&isBlocked(t.url)){
        logViolation("🚨 AI_TAB_OPENED",t.url);
      }
    }catch(e){}
  },1000);
});

// Listen for messages from popup
chrome.runtime.onMessage.addListener((msg,sender,sendResponse)=>{
  if(msg.action==="start"){
    studentName=msg.name;
    examActive=true;
    violations=[];
    tabLog=[];
    save();
    sendResponse({ok:true});
  }else if(msg.action==="stop"){
    examActive=false;
    save();
    sendResponse({ok:true,violations:violations.length});
  }else if(msg.action==="status"){
    sendResponse({examActive,studentName,violations:violations.length,log:violations});
  }
  return true;
});
