// Wait for verified login state before the first page view or queued event.
// No identifiers are returned by the context endpoint or added here.
export const GA_BOOTSTRAP = String.raw`
window.dataLayer=window.dataLayer||[];
(function(){
  var pending=[],ready=false,disabled=false,started=false,loading=false;
  function send(){window.dataLayer.push(arguments);}
  window.gtag=function(){
    if(disabled)return;
    if(ready)send.apply(null,arguments);
    else pending.push(Array.prototype.slice.call(arguments));
  };
  if(location.pathname==='/reset'||/(^|;\s*)pz_noga=1/.test(document.cookie)){
    disabled=true;return;
  }
  function refresh(){
  if(loading||document.visibilityState==='hidden')return;
  loading=true;ready=false;disabled=false;
  window['ga-disable-G-G3GZC8PBVD']=true;
  fetch('/api/analytics/context',{credentials:'same-origin',cache:'no-store',signal:AbortSignal.timeout(3000)})
    .then(function(r){if(!r.ok)throw new Error('analytics context');return r.json();})
    .then(function(context){
      if(document.visibilityState==='hidden'||context.excluded||!['member','guest'].includes(context.member_status)){
        disabled=true;pending=[];return;
      }
      window['ga-disable-G-G3GZC8PBVD']=false;
      if(!started)send('js',new Date());
      send('set',{member_status:context.member_status});
      send('config','G-G3GZC8PBVD',{member_status:context.member_status,send_page_view:!started});
      started=true;
      ready=true;
      pending.forEach(function(args){send.apply(null,args);});
      pending=[];
    }).catch(function(){disabled=true;pending=[];}).finally(function(){loading=false;});
  }
  window.addEventListener?.('focus',refresh);
  document.addEventListener?.('visibilitychange',function(){
    if(document.visibilityState==='visible')refresh();
    else {ready=false;disabled=true;pending=[];window['ga-disable-G-G3GZC8PBVD']=true;}
  });
  refresh();
})();
`;
