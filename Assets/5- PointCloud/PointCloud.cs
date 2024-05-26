using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;

/// <summary>
/// Utilizes the PointCloud shader to render 1000 rounded boxes, which are pushed outward from the center of a sphere by an explosion effect.
/// This code was developed for training purposes during a course and could be refactored for cleaner code and improved performance.
/// </summary>
[ExecuteInEditMode]
public class PointCloud : MonoBehaviour
{
    [SerializeField]
    bool isDirty = true;    // Bool button that respawn all the point clouds

    [SerializeField]
    bool animate = false;   // Bool button that animate the point clouds

    [SerializeField, Range(-10, 10)]
    float dragCoef = 1;     

    [SerializeField, Range(-10,  10)]
    float gravity = 1;

    [SerializeField, Range(1, 100000)]
    int nbrClouds = 1000;

    MeshFilter meshFilter;

    Vector3[]  vertices;
    Vector3[] speeds;


    bool IsPointCloudValid => speeds != null && speeds.Length > 0 && vertices != null && vertices.Length > 0;

    void Start()
    {
        meshFilter = GetComponent<MeshFilter>();
    }

    void Update()
    {
        if(meshFilter == null)
            meshFilter = GetComponent<MeshFilter>();
            
        if (isDirty)
        {
            UpdateShape();
            isDirty=false;
        }

        if(animate && IsPointCloudValid)
        {
            MoveVertices();
            meshFilter.sharedMesh.SetVertices(vertices);
            meshFilter.sharedMesh.RecalculateBounds();
        }
    }

    void MoveVertices()
    { 
        Vector3 _finalGravity = - gravity * Vector3.up;

        float _dt = Time.deltaTime;

        // Update Speed
        Parallel.For(0, speeds.Length,
        _index => {
            Vector3 _drag = -dragCoef * speeds[_index];
            speeds[_index] = speeds[_index] + (_finalGravity + _drag) * _dt;
        });

        // Update pos
        Parallel.For(0, vertices.Length,
        _index => {
            vertices[_index] = vertices[_index] + speeds[_index] * _dt;
            });
    }

    Mesh CreateMesh()
    {
        Mesh _mesh = new Mesh();

        float _extent = 100.0f;
        vertices = new Vector3[nbrClouds];
        speeds = new Vector3[nbrClouds];

        // Giving a random speed to each clouds.
        for (int i = 0; i < nbrClouds; i++)
        {
            speeds[i] = Random.Range(0.2f, 1.0f) * _extent * new Vector3(Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f)).normalized;
            vertices[i] = Vector3.zero;
        }

        Vector2[] _radii = new Vector2[nbrClouds];
        for (int i = 0;i < nbrClouds; i++)
            _radii[i] = new Vector2(Random.Range(0.0f, 0.1f), 0);

        _mesh.SetVertices(vertices);

        _mesh.SetUVs(0, _radii);

        // MeshTopology.Points should correspond to GeometryShader input topology
        _mesh.SetIndices(ComputeIndices(vertices), MeshTopology.Points, 0);

        return _mesh;
    }

    int[] ComputeIndices(Vector3[] _vertices)
    {
        int[] _indices = new int[_vertices.Length];
        for (int i = 0; i < _vertices.Length; i++)
        {
            _indices[i] = i;
        }

        return _indices;
    }

    void UpdateShape()
    {
        MeshFilter _meshFilter = GetComponent<MeshFilter>();
        _meshFilter.mesh = CreateMesh();
    }
}



