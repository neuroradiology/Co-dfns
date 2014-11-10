#include "h.cuh"

/* Nothing really works here */
I codfns_indexgenm(A*z,A*l,A*r,A**ig,I g){g2h(r);typ(z)=2;I64*c=(I64*)elm(r);
 scale(z,1,*c);shp(z)[0]=*c;I64*d=(I64*)elm(z);DO(*c,d[i]=i);ong(z)=0;R 0;}
__global__ V squaddgi(I64*z,I64 row,I64*r,UI64 sz){
 I64 i=blockDim.x*blockIdx.x+threadIdx.x;if(i<sz)z[i]=r[row*sz+i];}
__global__ V squaddgd(D*z,I64 row,D*r,UI64 sz){
 I64 i=blockDim.x*blockIdx.x+threadIdx.x;if(i<sz)z[i]=r[row*sz+i];}
I codfns_squadd(A*z,A*l,A*r,A**ig,I g){h2g(r);g2h(l);scale(z,1,shp(r)[1]);
 typ(z)=typ(r);I64 row=*((I64*)elm(l));shp(z)[0]=shp(r)[1];
 UI64 bs=(siz(z)+1024-1)/1024;
 if(typ(z)==3)squaddgd<<<bs,1024>>>((D*)gpu(z),row,(D*)gpu(r),siz(z));
 else squaddgi<<<bs,1024>>>((I64*)gpu(z),row,(I64*)gpu(r),siz(z));
 /*if(typ(z)==3){D*e=(D*)elm(r);e+=*row*siz(z);cp(elm(z),e,D,siz(z));}
 else{I64*e=(I64*)elm(r);e+=*row*siz(z);cp(elm(z),e,I64,siz(z));};*/
 ong(z)=1;R 0;}
__global__ V indexdg(I64*z,I64*l,I64*r,UI64 sz){
 I64 i=blockDim.x*blockIdx.x+threadIdx.x;if(i<sz)z[i]=r[l[i]];}
I codfns_indexd(A*z,A*l,A*r,A**ig,I g){h2g(l);h2g(r);I64*le=(I64*)gpu(l);
 typ(z)=typ(r);I64*re=(I64*)gpu(r);I64*ze;prep((V**)&ze,z,l);ze=(I64*)gpu(z);
 UI64 bs=(siz(r)+1024-1)/1024;indexdg<<<bs,1024>>>(ze,le,re,siz(z));
 ong(z)=1;R 0;}
I codfns_reshapem(A*z,A*l,A*r,A**ig,I g){g2h(r);scale(z,1,rnk(r));
 typ(z)=2;*shp(z)=rnk(r);I64*e=(I64*)elm(z);DO(rnk(r),e[i]=shp(r)[i]);
 ong(z)=0;R 0;}
I codfns_reshaped(A*z,A*l,A*r,A**ig,I g){g2h(l);g2h(r);
 UI64 s=tr(siz(l),(UI64*)elm(l));scale(z,siz(l),s);
 typ(z)=typ(r);I64*le=(I64*)elm(l);UI64 rs=siz(r);DO(siz(l),shp(z)[i]=le[i]);
 if(typ(z)==3){D*e=(D*)elm(z);D*re=(D*)elm(r);DO(s,e[i]=re[i%rs]);}
 else{I64*e=(I64*)elm(z);I64*re=(I64*)elm(r);DO(s,e[i]=re[i%rs]);};
 ong(z)=0;R 0;}
I codfns_catenated(A*z,A*l,A*r,A**ig,I g){g2h(l);g2h(r);
 UI64 lsz=siz(l);UI64 rsz=siz(r);
 UI64 sz=lsz+rsz;scale(z,1,sz);*shp(z)=sz;typ(z)=typ(l);
 if(typ(z)==3){D*ze=(D*)elm(z);D*le=(D*)elm(l);D*re=(D*)elm(r);
  if(r==z){DO(rsz,ze[lsz+i]=re[i]);DO(lsz,ze[i]=le[i]);}
  else if(l==z){DO(rsz,ze[lsz+i]=re[i]);}
  else{DO(lsz,ze[i]=le[i]);DO(rsz,ze[lsz+i]=re[i]);}}
 else{I64*ze=(I64*)elm(z);I64*le=(I64*)elm(l);I64*re=(I64*)elm(r);
  if(r==z){DO(rsz,ze[lsz+i]=re[i]);DO(lsz,ze[i]=le[i]);}
  else if(l==z){DO(rsz,ze[lsz+i]=re[i]);}
  else{DO(lsz,ze[i]=le[i]);DO(rsz,ze[lsz+i]=re[i]);}}
 ong(z)=0;R 0;}
I codfns_ptredd(A*z,A*l,A*r,A**ig,I g){g2h(l);g2h(r);
 D*le=(D*)elm(l);D*re=(D*)elm(r);D v=0;
 DO(siz(r),v+=le[i]*re[i]);scale(z,0,1);*((D*)elm(z))=v;ong(z)=0;R 0;}
I codfns_eachm(A*z,A*l,A*r,I(*f)(A*,A*,A*,A**,I),A**e,I g){g2h(r);
 D*ze;prep((V**)&ze,z,r);
 A sz={0,0,0,2,0,NULL,NULL,NULL};A sr={0,1,1,typ(r),0,NULL,elm(r),NULL};
 DO(siz(z),elm(&sr)=&((D*)elm(r))[i];f(&sz,NULL,&sr,e,0);ze[i]=*(D*)elm(&sz));
 typ(z)=typ(&sz);array_free(&sz);ong(z)=0;R 0;}
