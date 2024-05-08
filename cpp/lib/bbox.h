#ifndef BBOX_H
#define BBOX_H

#include <algorithm>
#include <cfloat>
#include <cmath>
#include <ostream>
#include <vector>

#include "mat4.h"
#include "ray.h"
#include "vec2.h"
#include "vec3.h"

struct BBox {

    /// Default min is max float value, default max is negative max float value
    BBox() : min(FLT_MAX), max(-FLT_MAX) {
    }
    /// Set minimum and maximum extent
    explicit BBox(Vec3 min, Vec3 max) : min(min), max(max) {
    }

    BBox(const BBox&) = default;
    BBox& operator=(const BBox&) = default;
    ~BBox() = default;

    /// Rest min to max float, max to negative max float
    void reset() {
        min = Vec3(FLT_MAX);
        max = Vec3(-FLT_MAX);
    }

    /// Expand bounding box to include point
    void enclose(Vec3 point) {
        min = hmin(min, point);
        max = hmax(max, point);
    }
    void enclose(BBox box) {
        min = hmin(min, box.min);
        max = hmax(max, box.max);
    }

    /// Get center point of box
    Vec3 center() const {
        return (min + max) * 0.5f;
    }

    // Check whether box has no volume
    bool empty() const {
        return min.x > max.x || min.y > max.y || min.z > max.z;
    }

    /// Get surface area of the box
    float surface_area() const {
        if(empty()) return 0.0f;
        Vec3 extent = max - min;
        return 2.0f * (extent.x * extent.z + extent.x * extent.y + extent.y * extent.z);
    }

    /// Transform box by a matrix
    void transform(const Mat4& trans) {
        Vec3 amin = min, amax = max;
        min = max = trans[3].xyz();
        for(int i = 0; i < 3; i++) {
            for(int j = 0; j < 3; j++) {
                float a = trans[j][i] * amin[j];
                float b = trans[j][i] * amax[j];
                if(a < b) {
                    min[i] += a;
                    max[i] += b;
                } else {
                    min[i] += b;
                    max[i] += a;
                }
            }
        }
    }

    bool hit(const Ray& ray, Vec2& times) const {
        
        // hit distances
        float tx0, tx1, ty0, ty1, tz0, tz1;

        // plane locations
        float x0 = min.x;
        float x1 = max.x;
        float y0 = min.y;
        float y1 = max.y;
        float z0 = min.z;
        float z1 = max.z;

        // if there is no direction component of the ray in a certain direction, it will never intersect with those planes
        bool has_x_comp = (ray.dir.x != 0);
        bool has_y_comp = (ray.dir.y != 0);
        bool has_z_comp = (ray.dir.z != 0);

        // compute hit values
        if (has_x_comp) {
            float a_x = 1.0f/ray.dir.x;
            float b_x = -ray.point.x / ray.dir.x;
            tx0 = a_x*x0 + b_x;
            tx1 = a_x*x1 + b_x;
            if (tx0 > tx1) std::swap(tx0, tx1);
        } else {
            tx0 = -INFINITY;
            tx1 = INFINITY;
            // if ray has no x component, it can't hit the box if not already within the BBox's x bounds
            if ((ray.point.x < x0) || (ray.point.x > x1)) return false;
        }

        if (has_y_comp) {
            float a_y = 1.0f/ray.dir.y;
            float b_y = -ray.point.y / ray.dir.y;
            ty0 = a_y*y0 + b_y;
            ty1 = a_y*y1 + b_y;
            if (ty0 > ty1) std::swap(ty0, ty1);
        } else {
            ty0 = -INFINITY;
            ty1 = INFINITY;
            // if ray has no y component, it can't hit the box if not already within the BBox's y bounds
            if ((ray.point.y < y0) || (ray.point.y > y1)) return false;
        }

        if (has_z_comp) {
            float a_z = 1.0f/ray.dir.z;
            float b_z = -ray.point.z / ray.dir.z;
            tz0 = a_z*z0 + b_z;
            tz1 = a_z*z1 + b_z;
            if (tz0 > tz1) std::swap(tz0, tz1);
        } else {
            tz0 = -INFINITY;
            tz1 = INFINITY;
            // if ray has no z component, it can't hit the box if not already within the BBox's z bounds
            if ((ray.point.z < z0) || (ray.point.z > z1)) return false;
        }

        // calculate intersection bounds of hit ranges
        float time_lower_bound = std::max(std::max(tx0, ty0), tz0);
        float time_upper_bound = std::min(std::min(tx1, ty1), tz1);

        // if ranges don't have a union, we miss the box
        if (time_lower_bound > time_upper_bound) return false;
        
        // if ranges do have a union, update time bounds and return a hit
        times.x = std::max(time_lower_bound, times.x);
        times.y = std::min(time_upper_bound, times.y);

        return true;
    }

    /// Get the eight corner points of the bounding box
    std::vector<Vec3> corners() const {
        std::vector<Vec3> ret(8);
        ret[0] = Vec3(min.x, min.y, min.z);
        ret[1] = Vec3(max.x, min.y, min.z);
        ret[2] = Vec3(min.x, max.y, min.z);
        ret[3] = Vec3(min.x, min.y, max.z);
        ret[4] = Vec3(max.x, max.y, min.z);
        ret[5] = Vec3(min.x, max.y, max.z);
        ret[6] = Vec3(max.x, min.y, max.z);
        ret[7] = Vec3(max.x, max.y, max.z);
        return ret;
    }

    /// Given a screen transformation (projection), calculate screen-space ([-1,1]x[-1,1])
    /// bounds that will always contain the bounding box on screen
    void screen_rect(const Mat4& transform, Vec2& min_out, Vec2& max_out) const {

        min_out = Vec2(FLT_MAX);
        max_out = Vec2(-FLT_MAX);
        auto c = corners();
        bool partially_behind = false, all_behind = true;
        for(auto& v : c) {
            Vec3 p = transform * v;
            if(p.z < 0) {
                partially_behind = true;
            } else {
                all_behind = false;
            }
            min_out = hmin(min_out, Vec2(p.x, p.y));
            max_out = hmax(max_out, Vec2(p.x, p.y));
        }

        if(partially_behind && !all_behind) {
            min_out = Vec2(-1.0f, -1.0f);
            max_out = Vec2(1.0f, 1.0f);
        } else if(all_behind) {
            min_out = Vec2(0.0f, 0.0f);
            max_out = Vec2(0.0f, 0.0f);
        }
    }

    Vec3 min, max;
};

inline std::ostream& operator<<(std::ostream& out, BBox b) {
    out << "BBox{" << b.min << "," << b.max << "}";
    return out;
}

#endif
