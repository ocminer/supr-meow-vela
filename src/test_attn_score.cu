// Exercise the actual inlined CUDA score helper against int64 dot products.
#include "attn.cu"
#include <algorithm>
#include <cstdio>
#include <random>
#include <vector>
namespace meow {
__global__ void score_check_k(const int3* v, int* out, int n) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n) out[i]=score(v[i].x,v[i].y,v[i].z);
}
__global__ void probability_check_k(const uint3* v, unsigned* out, int n) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n) out[i]=probability_round(v[i].x,v[i].y,v[i].z);
}
}
static int testProbability() {
    std::mt19937_64 gen(86020261027ULL);
    std::vector<uint3> inputs; std::vector<unsigned> expected;
    auto add=[&](uint64_t sum, unsigned e) {
        const uint64_t r=sum ? (1ULL<<62)/sum : 0;
        inputs.push_back(make_uint3(e,unsigned(r),unsigned(r>>32)));
        // The complete product is bounded by 2^62, so uint64 is exact.
        expected.push_back(unsigned(((uint64_t(e)*r)+(1ULL<<46))>>47));
    };
    add(0,0);
    for(int k=0;k<=42;++k) for(int d=-1;d<=1;++d) {
        const int64_t s=(1LL<<k)+d; if(s<=0)continue;
        const unsigned e=unsigned(std::min<uint64_t>(s,1ULL<<30));
        for(unsigned v:{0u,1u,e/2,e-1,e})add(s,v);
    }
    for(int i=0;i<100000;++i) {
        const uint64_t sum=1+(gen()%((1ULL<<42)-1));
        add(sum,unsigned(gen()%(std::min<uint64_t>(sum,1ULL<<30)+1)));
    }
    uint3* dv=nullptr;unsigned* dout=nullptr;const size_t n=inputs.size();
    if(cudaMalloc(&dv,n*sizeof(uint3))!=cudaSuccess || cudaMalloc(&dout,n*sizeof(unsigned))!=cudaSuccess)return 6;
    if(cudaMemcpy(dv,inputs.data(),n*sizeof(uint3),cudaMemcpyHostToDevice)!=cudaSuccess)return 7;
    meow::probability_check_k<<<(n+255)/256,256>>>(dv,dout,int(n));
    std::vector<unsigned> got(n);
    if(cudaGetLastError()!=cudaSuccess || cudaMemcpy(got.data(),dout,n*sizeof(unsigned),cudaMemcpyDeviceToHost)!=cudaSuccess)return 8;
    for(size_t i=0;i<n;++i)if(got[i]!=expected[i]){std::printf("probability FAIL %zu: %u != %u\n",i,got[i],expected[i]);return 9;}
    cudaFree(dout);cudaFree(dv);
    std::printf("probability PASS: %zu actual CUDA cases against full-width reference, including high reciprocal limbs\n",n);
    return 0;
}
int main() {
    std::mt19937 gen(12089); std::vector<int3> inputs; std::vector<int> expected;
    const int edges[]={-32767,-32766,-32513,-256,-255,-128,-1,0,1,127,128,255,256,32512,32766,32767};
    for(int test=0;test<10000;++test) {
        int64_t hh=0,hl=0,lh=0,ll=0,qhs=0,qls=0,ks=0,dot=0;
        for(int d=0;d<64;++d) {
            int q=test<256?edges[test/16]:int(gen()%65535)-32767;
            int k=test<256?edges[test%16]:int(gen()%65535)-32767;
            int qh=q>>8, ql=(q&255)-128, kh=k>>8, kl=(k&255)-128;
            hh+=qh*kh;hl+=qh*kl;lh+=ql*kh;ll+=ql*kl;qhs+=qh;qls+=ql;ks+=k;dot+=int64_t(q)*k;
        }
        int64_t t=256*(hl+lh)+ll+32768*qhs+128*qls+128*ks;
        if(t<INT_MIN || t>INT_MAX || dot!=65536*hh+t) return 1;
        for(int sh=-13;sh<=19;++sh) {
            inputs.push_back(make_int3(int(hh),int(t),sh));
            int64_t v=sh>0?(dot+(1LL<<(sh-1)))>>sh:sh==0?dot:dot*(1LL<<(-sh));
            expected.push_back(int(v<INT_MIN?INT_MIN:v>INT_MAX?INT_MAX:v));
        }
    }
    int3* dv=nullptr;int* dout=nullptr; size_t n=inputs.size();
    if(cudaMalloc(&dv,n*sizeof(int3))!=cudaSuccess || cudaMalloc(&dout,n*sizeof(int))!=cudaSuccess) return 2;
    if(cudaMemcpy(dv,inputs.data(),n*sizeof(int3),cudaMemcpyHostToDevice)!=cudaSuccess) return 3;
    meow::score_check_k<<<(n+255)/256,256>>>(dv,dout,int(n));
    std::vector<int> got(n);
    if(cudaGetLastError()!=cudaSuccess || cudaMemcpy(got.data(),dout,n*sizeof(int),cudaMemcpyDeviceToHost)!=cudaSuccess) return 4;
    for(size_t i=0;i<n;++i) if(got[i]!=expected[i]) {std::printf("FAIL %zu: %d != %d\n",i,got[i],expected[i]);return 5;}
    cudaFree(dout);cudaFree(dv);
    std::printf("score PASS: %zu actual CUDA scores against exact int64 dot products; shifts -13..19, signed extrema and random quantised operands\n",n);
    return testProbability();
}
