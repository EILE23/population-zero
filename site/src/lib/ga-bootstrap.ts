// Wait for verified login state before the first page view or queued event.
// No identifiers are returned by the context endpoint or added here.
export const GA_BOOTSTRAP = String.raw`
window.dataLayer=window.dataLayer||[];
(function(){
  var pending=[],ready=false,disabled=false;
  function send(){window.dataLayer.push(arguments);}
  window.gtag=function(){
    if(disabled)return;
    if(ready)send.apply(null,arguments);
    else pending.push(Array.prototype.slice.call(arguments));
  };
  if(location.pathname==='/reset'||/(^|;\s*)pz_noga=1/.test(document.cookie)){
    disabled=true;return;
  }
  fetch('/api/analytics/context',{credentials:'same-origin',cache:'no-store',signal:AbortSignal.timeout(3000)})
    .then(function(r){if(!r.ok)throw new Error('analytics context');return r.json();})
    .then(function(context){
      if(context.excluded||!['member','guest'].includes(context.member_status)){
        disabled=true;pending=[];return;
      }
      send('js',new Date());
      send('set',{member_status:context.member_status});
      send('config','G-G3GZC8PBVD',{member_status:context.member_status});
      ready=true;
      pending.forEach(function(args){send.apply(null,args);});
      pending=[];
    }).catch(function(){disabled=true;pending=[];});
})();
`;
