const std = @import("std");
const math = @import("math.zig");
const ray = @import("ray.zig");

const Vec3 = math.Vec3;
const Point3 = ray.Point3;
const Ray = ray.Ray;

// Hit record stores information about a ray-object intersection
pub const HitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f64,
    front_face: bool,

    const Self = @This();

    // Sets the hit record normal vector.
    // NOTE: the parameter `outward_normal` is assumed to have unit length.
    // The normal is always set to point against the ray direction.
    pub fn setFaceNormal(self: *Self, r: Ray, outward_normal: Vec3) void {
        // front_face is true if ray is hitting the front face (ray and normal point in opposite directions)
        self.front_face = r.dir.dot(outward_normal) < 0;
        // Normal always points against the ray direction
        self.normal = if (self.front_face) outward_normal else outward_normal.neg();
    }
};

// Union type for different hittable objects
// Can be extended to include other types (Plane, Triangle, etc.)
pub const Hittable = union(enum) {
    sphere: Sphere,
    // Add more types here as needed:
    // plane: Plane,
    // triangle: Triangle,

    // Generic hit method that dispatches to the appropriate type
    pub fn hit(self: *const Hittable, r: Ray, ray_tmin: f64, ray_tmax: f64, rec: *HitRecord) bool {
        return switch (self.*) {
            .sphere => |*s| s.hit(r, ray_tmin, ray_tmax, rec),
            // .plane => |*p| p.hit(r, ray_tmin, ray_tmax, rec),
        };
    }
};

// List of hittable objects
pub const HittableList = struct {
    objects: std.ArrayList(Hittable),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .objects = std.ArrayList(Hittable).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.objects.deinit(self.allocator);
    }

    pub fn clear(self: *Self) void {
        self.objects.clearRetainingCapacity();
    }

    pub fn add(self: *Self, object: Hittable) !void {
        try self.objects.append(self.allocator, object);
    }

    pub fn hit(self: *const Self, r: Ray, ray_tmin: f64, ray_tmax: f64, rec: *HitRecord) bool {
        var temp_rec = HitRecord{
            .p = undefined,
            .normal = undefined,
            .t = 0,
            .front_face = false,
        };
        var hit_anything = false;
        var closest_so_far = ray_tmax;

        for (self.objects.items) |object| {
            if (object.hit(r, ray_tmin, closest_so_far, &temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec.* = temp_rec;
            }
        }

        return hit_anything;
    }
};

// Sphere implementation of hittable
pub const Sphere = struct {
    center: Point3,
    radius: f64,

    const Self = @This();

    pub fn init(center: Point3, radius: f64) Self {
        // Ensure radius is non-negative (equivalent to std::fmax(0, radius))
        const safe_radius = @max(0.0, radius);
        return Self{
            .center = center,
            .radius = safe_radius,
        };
    }

    pub fn hit(self: *const Self, r: Ray, ray_tmin: f64, ray_tmax: f64, rec: *HitRecord) bool {
        // Vector from ray origin to sphere center
        const oc = self.center.sub(r.orig);

        // Optimized quadratic equation for ray-sphere intersection
        const a = r.dir.lengthSquared();
        const h = r.dir.dot(oc);
        const c = oc.lengthSquared() - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) {
            return false;
        }

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range
        var root = (h - sqrtd) / a;
        if (root <= ray_tmin or root >= ray_tmax) {
            root = (h + sqrtd) / a;
            if (root <= ray_tmin or root >= ray_tmax) {
                return false;
            }
        }

        // Fill hit record
        rec.t = root;
        rec.p = r.at(rec.t);
        // Calculate outward normal (from center to intersection point, normalized)
        const outward_normal = rec.p.sub(self.center).divScalar(self.radius);
        // Set face normal (determines front_face and ensures normal points against ray)
        rec.setFaceNormal(r, outward_normal);

        return true;
    }
};
