#ifndef TRIANGLE_H
#define TRIANGLE_H

#include "vec3.h"
#include "spectrum.h"

struct Triangle {

    Triangle() {
        v0 = Vec3();
        v1 = Vec3();
        v2 = Vec3();
    }

    explicit Triangle(Vec3 _v0, Vec3 _v1, Vec3 _v2) {
        v0 = _v0;
        v1 = _v1;
        v2 = _v2;
    }

    Vec3 v0, v1, v2;
    Vec3 normal;

    uint8_t material;
    Spectrum color;

};

#endif