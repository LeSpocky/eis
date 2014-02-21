#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/CLAMD_REGIONS.sh
# Creation:    2010-08-05 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="$p2"

    sellist="ac,ad,ae,af,ag,ai,al,am,an,ao,aq,ar,as,at,au,aw,ax,az,ba,bb,bd,be"
    sellist="$sellist,bf,bg,bh,bi,bj,bm,bn,bo,br,bs,bt,bv,bw,by,bz,ca,cc,cd,cf"
    sellist="$sellist,cg,ch,ci,ck,cl,cm,cn,co,cr,cs,cu,cv,cx,cy,cz,de,dj,dk,dm"
    sellist="$sellist,do,dz,ec,ee,eg,eh,er,es,et,fi,fj,fk,fm,fo,fr,ga,gb,gd,ge"
    sellist="$sellist,gf,gg,gh,gi,gl,gm,gn,gp,gq,gr,gs,gt,gu,gw,gy,hk,hm,hn,hr"
    sellist="$sellist,ht,hu,id,ie,il,im,in,io,iq,ir,is,it,je,jm,jo,jp,ke,kg,kh"
    sellist="$sellist,ki,km,kn,kp,kr,kw,ky,kz,la,lb,lc,li,lk,lr,ls,lt,lu,lv,ly"
    sellist="$sellist,ma,mc,md,mg,mh,mk,ml,mm,mn,mo,mp,mq,mr,ms,mt,mu,mv,mw,mx"
    sellist="$sellist,my,mz,na,nc,ne,nf,ng,ni,nl,no,np,nr,nu,nz,om,pa,pe,pf,pg"
    sellist="$sellist,ph,pk,pl,pm,pn,pr,ps,pt,pw,py,qa,re,ro,ru,rw,sa,sb,sc,sd"
    sellist="$sellist,se,sg,sh,si,sj,sk,sl,sm,sn,so,sr,st,sv,sy,sz,tc,td,tf,tg"
    sellist="$sellist,th,tj,tk,tl,tm,tn,to,tp,tr,tt,tv,tw,tz,ua,ug,uk,um,us,uy"
    sellist="$sellist,uz,va,vc,ve,vg,vi,vn,vu,wf,ws,ye,yt,yu,za,zm,zw"
    ece_select_list_dlg "$win" "Regions" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
